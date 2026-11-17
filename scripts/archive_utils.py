"""Deterministic, bounded archive primitives for local release packaging.

Only regular files (and reader-side directories) are supported. Names are relative
POSIX paths; tar readers also accept a conventional leading ``./`` and one root
directory. No reader extracts to disk. All invalid/unsupported inputs raise
ArchiveError, a ValueError subclass. Limits apply before payload decompression.

Epochs are integer Unix seconds in 0..999999999999 (normal ar's 12-digit domain).
Gzip header time clamps to uint32; tar/ar preserve the epoch. ZIP times are UTC,
clamped to 1980..2107, and rounded down to DOS two-second precision.
Byte reproducibility assumes the same Python/zlib implementation. ZIP64,
multi-disk ZIP, encrypted ZIP, non-gzip Debian payloads, GNU/BSD extended ar,
global/stacked PAX headers, sparse tar, and PAX size/link/extension keys are
unsupported.
"""

import datetime
import gzip
import io
import stat
import struct
import tarfile
import unicodedata
import zipfile
import zlib


MAX_MEMBERS = 4096  # Includes directories and physical tar extension headers.
MAX_FILE_SIZE = 256 * 1024 * 1024
MAX_TOTAL_SIZE = 512 * 1024 * 1024
MAX_ARCHIVE_SIZE = 512 * 1024 * 1024
MAX_PATH_BYTES = 4096
MAX_DEPTH = 32
MAX_METADATA_SIZE = 16 * 1024
_DEB_NAMES = ("debian-binary", "control.tar.gz", "data.tar.gz")
_PAX_KEYS = frozenset(("path", "mtime", "atime", "ctime", "uid", "gid", "uname", "gname"))


class ArchiveError(ValueError):
    """Invalid, unsafe, unsupported, or over-limit archive input."""


def _epoch(epoch):
    if type(epoch) is not int or not 0 <= epoch <= 999999999999:
        raise ArchiveError("epoch must be an integer in 0..999999999999")
    return epoch


def _raw(raw):
    if not isinstance(raw, bytes) or len(raw) > MAX_ARCHIVE_SIZE:
        raise ArchiveError("archive must be bytes within the archive size limit")
    return raw


def _name(name, *, directory=False, tar=False):
    if not isinstance(name, str) or not name:
        raise ArchiveError("empty or non-string archive path")
    if "\\" in name or any(unicodedata.category(c) in ("Cc", "Cf", "Cs") for c in name):
        raise ArchiveError("control or backslash in archive path")
    if tar:
        while name.startswith("./"):
            name = name[2:]
        if directory and name in ("", "."):
            return ""
    if directory and name.endswith("/"):
        name = name[:-1]
    parts = name.split("/")
    if (not name or len(parts) > MAX_DEPTH or len(name.encode("utf-8")) > MAX_PATH_BYTES
            or any(p in ("", ".", "..") or ":" in p for p in parts)):
        raise ArchiveError("unsafe or over-limit archive path")
    return name


def _mode(mode):
    if (type(mode) is not int or mode < 0 or mode > 0o177777
            or stat.S_IFMT(mode) not in (0, stat.S_IFREG)):
        raise ArchiveError("entry mode must describe a regular file")
    return 0o755 if mode & 0o111 else 0o644


def _tree(files, directories):
    """Reject file/directory aliases and derive all parent directories."""
    result = set(directories)
    for name in set(files) | result.copy():
        parts = name.split("/")
        result.update("/".join(parts[:i]) for i in range(1, len(parts)))
    if set(files) & result:
        raise ArchiveError("file/directory path conflict")
    if len(files) + len(result) > MAX_MEMBERS:
        raise ArchiveError("archive member count limit exceeded")
    return result


def _entries(entries):
    files = {}
    total = 0
    try:
        entries = iter(entries)
    except TypeError as error:
        raise ArchiveError("entries must be iterable") from error
    for entry in entries:
        try:
            name, data, mode = entry
        except (TypeError, ValueError) as error:
            raise ArchiveError("entries must be (name, bytes, mode) triples") from error
        name = _name(name)
        if name in files:
            raise ArchiveError("duplicate archive path")
        if not isinstance(data, bytes) or len(data) > MAX_FILE_SIZE:
            raise ArchiveError("entry must be bytes within the file size limit")
        total += len(data)
        if total > MAX_TOTAL_SIZE or len(files) >= MAX_MEMBERS:
            raise ArchiveError("archive content limits exceeded")
        files[name] = (data, _mode(mode))
    directories = _tree(files, set())
    return files, directories


def deterministic_zip(entries, epoch):
    """Return a canonical stored ZIP of FILES (name, bytes, mode) triples.

    Stored ZIP avoids deflate variability for IPA packaging. Executability is
    preserved; all other permission bits become 0644/0755. Parent directories
    are implicit. Input order and host environment do not affect the output.
    """
    epoch = _epoch(epoch)
    files, _ = _entries(entries)
    stamp = datetime.datetime.fromtimestamp(max(315532800, min(epoch, 4354819199)),
                                             datetime.timezone.utc)
    date_time = (stamp.year, stamp.month, stamp.day, stamp.hour, stamp.minute,
                 stamp.second // 2 * 2)
    target = io.BytesIO()
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_STORED, allowZip64=False) as archive:
        for name in sorted(files):
            data, mode = files[name]
            info = zipfile.ZipInfo(name, date_time)
            info.create_system = 3
            info.create_version = 20
            info.extract_version = 20
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_STORED
            archive.writestr(info, data)
    return _raw(target.getvalue())


def _gzip(data, epoch):
    output = io.BytesIO()
    # GzipFile fixes OS=255 and omits FNAME; gzip.compress differs across Python
    # releases when mtime=0 and delegates its header to zlib on some versions.
    with gzip.GzipFile(filename="", mode="wb", fileobj=output, compresslevel=9,
                       mtime=min(epoch, 0xFFFFFFFF)) as stream:
        stream.write(data)
    return output.getvalue()


def _tar(files, directories, epoch):
    target = io.BytesIO()
    with tarfile.open(fileobj=target, mode="w", format=tarfile.PAX_FORMAT,
                      encoding="utf-8", errors="strict") as archive:
        for name in sorted(set(files) | directories):
            info = tarfile.TarInfo(name)
            info.mtime = epoch
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            if name in directories:
                info.type, info.mode = tarfile.DIRTYPE, 0o755
                archive.addfile(info)
            else:
                data, info.mode = files[name]
                info.type, info.size = tarfile.REGTYPE, len(data)
                archive.addfile(info, io.BytesIO(data))
    raw = target.getvalue()
    _tar_layout(raw)  # Enforce physical header limits on generated PAX archives.
    return _raw(_gzip(raw, epoch))


def deterministic_tar_gz(entries, epoch):
    """Return canonical PAX tar/gzip of FILES, deriving 0755 parent directories."""
    epoch = _epoch(epoch)
    files, directories = _entries(entries)
    return _tar(files, directories, epoch)


def _gunzip(raw):
    # A cap on decompressed tar bytes also bounds padding and hidden metadata.
    maximum = MAX_TOTAL_SIZE + MAX_MEMBERS * 1024 + tarfile.RECORDSIZE
    try:
        stream = zlib.decompressobj(16 + zlib.MAX_WBITS)
        data = stream.decompress(raw, maximum + 1)
        if len(data) > maximum or stream.unconsumed_tail:
            raise ArchiveError("gzip decompressed size limit exceeded")
        if not stream.eof or stream.unused_data:
            raise ArchiveError("truncated, concatenated, or trailing gzip data")
        return data
    except zlib.error as error:
        raise ArchiveError("invalid gzip data") from error


def _tar_layout(raw):
    """Check every physical header, including otherwise hidden PAX/GNU records."""
    if len(raw) % tarfile.BLOCKSIZE:
        raise ArchiveError("tar length is not a multiple of 512")
    offset = count = total = 0
    pending_extension = False
    while offset < len(raw):
        header = raw[offset:offset + tarfile.BLOCKSIZE]
        if header == bytes(tarfile.BLOCKSIZE):
            if pending_extension or len(raw) - offset < 1024 or any(raw[offset:]):
                raise ArchiveError("invalid tar terminator or trailing data")
            return
        count += 1
        if count > MAX_MEMBERS:
            raise ArchiveError("tar header count limit exceeded")
        try:
            info = tarfile.TarInfo.frombuf(header, "utf-8", "strict")
        except (tarfile.TarError, UnicodeError, ValueError) as error:
            raise ArchiveError("invalid tar header") from error
        for field in (header[:100], header[345:500] if header[257:263] == b"ustar\x00" else b""):
            if b"\x00" in field and any(field.split(b"\x00", 1)[1]):
                raise ArchiveError("embedded NUL in tar path field")
        _name(info.name, directory=True, tar=True)
        if info.size < 0:
            raise ArchiveError("negative tar payload size")
        if info.type in (tarfile.XHDTYPE, tarfile.GNUTYPE_LONGNAME):
            if pending_extension:
                raise ArchiveError("stacked tar extension headers are unsupported")
            if info.size > MAX_METADATA_SIZE:
                raise ArchiveError("tar metadata size limit exceeded")
            pending_extension = True
            payload = raw[offset + 512:offset + 512 + info.size]
            if info.type == tarfile.GNUTYPE_LONGNAME:
                name = payload.rstrip(b"\x00")
                if b"\x00" in name:
                    raise ArchiveError("embedded NUL in GNU long path")
                try:
                    _name(name.decode("utf-8"), directory=True, tar=True)
                except UnicodeError as error:
                    raise ArchiveError("invalid GNU long path encoding") from error
            else:
                _pax(payload)
        elif info.type in (tarfile.REGTYPE, tarfile.AREGTYPE):
            pending_extension = False
            total += info.size
            if info.size > MAX_FILE_SIZE or total > MAX_TOTAL_SIZE:
                raise ArchiveError("tar payload size limit exceeded")
        elif info.type != tarfile.DIRTYPE or info.size:
            raise ArchiveError("unsupported tar member type or directory payload")
        else:
            pending_extension = False
        offset += 512 + (info.size + 511) // 512 * 512
        if offset > len(raw):
            raise ArchiveError("truncated tar payload")
    raise ArchiveError("missing tar terminator")


def _pax(payload):
    """Validate all local records, including shadowed/otherwise ignored paths."""
    offset, seen = 0, set()
    while offset < len(payload):
        space = payload.find(b" ", offset)
        digits = payload[offset:space]
        if space < 0 or not digits or not digits.isdigit() or len(digits) > 8:
            raise ArchiveError("invalid PAX record length")
        size = int(digits)
        end = offset + size
        if size <= len(digits) + 3 or end > len(payload) or payload[end - 1:end] != b"\n":
            raise ArchiveError("truncated PAX record")
        try:
            key, value = payload[space + 1:end - 1].decode("utf-8").split("=", 1)
        except (UnicodeError, ValueError) as error:
            raise ArchiveError("invalid PAX record encoding") from error
        if key in seen or key not in _PAX_KEYS:
            raise ArchiveError("duplicate or unsupported PAX record")
        seen.add(key)
        if key == "path":
            _name(value, directory=True, tar=True)
        offset = end


def _tar_contents(raw):
    raw = _gunzip(_raw(raw))
    _tar_layout(raw)
    files, directories, seen = {}, set(), set()
    total = 0
    try:
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:", encoding="utf-8",
                          errors="strict") as archive:
            for info in archive:
                if not (info.isfile() or info.isdir()) or info.sparse is not None:
                    raise ArchiveError("unsupported tar member type")
                if not set(info.pax_headers) <= _PAX_KEYS:
                    raise ArchiveError("unsupported PAX keys")
                name = _name(info.name, directory=info.isdir(), tar=True)
                if name in seen:
                    raise ArchiveError("duplicate tar path")
                seen.add(name)
                if len(seen) > MAX_MEMBERS:
                    raise ArchiveError("tar member count limit exceeded")
                if info.isdir():
                    if info.size:
                        raise ArchiveError("directory contains a payload")
                    if name:
                        directories.add(name)
                else:
                    total += info.size
                    if info.size < 0 or info.size > MAX_FILE_SIZE or total > MAX_TOTAL_SIZE:
                        raise ArchiveError("tar payload size limit exceeded")
                    stream = archive.extractfile(info)
                    data = stream.read(info.size + 1)
                    if len(data) != info.size:
                        raise ArchiveError("truncated tar payload")
                    files[name] = (data, _mode(info.mode))
    except (tarfile.TarError, UnicodeError, OSError, EOFError, ValueError) as error:
        if isinstance(error, ArchiveError):
            raise
        raise ArchiveError("invalid tar archive") from error
    directories = _tree(files, directories)
    return files, directories


def read_tar_gz_safely(raw_bytes):
    """Validate one gzip stream containing plain/PAX/GNU-longname regular tar."""
    files, _ = _tar_contents(raw_bytes)
    return {name: files[name][0] for name in sorted(files)}


def _zip_layout(raw):
    # Bound central-directory parsing before ZipFile allocates one object per
    # member. ZIP64 is unnecessary within these limits and is refused.
    offset = raw.rfind(b"PK\x05\x06", max(0, len(raw) - 65557))
    if offset < 0 or offset + 22 > len(raw):
        raise ArchiveError("missing ZIP end record")
    _, disk, central_disk, disk_count, count, size, start, comment = struct.unpack_from("<4s4H2LH", raw, offset)
    if (disk or central_disk or disk_count != count or count > MAX_MEMBERS
            or count == 0xFFFF or size == 0xFFFFFFFF or start == 0xFFFFFFFF
            or start + size != offset or offset + 22 + comment != len(raw)):
        raise ArchiveError("unsupported or over-limit ZIP layout")
    # Canonical ZIPs have no executable prefix. Every local interval is checked
    # below, including optional data descriptors, so hidden entries are refused.
    if count and not raw.startswith(b"PK\x03\x04"):
        raise ArchiveError("ZIP preamble is unsupported")
    if not count and (start or size):
        raise ArchiveError("invalid empty ZIP layout")
    position, actual_count = start, 0
    while position < offset:
        if position + 46 > offset or raw[position:position + 4] != b"PK\x01\x02":
            raise ArchiveError("invalid ZIP central record")
        name_size, extra_size, comment_size = struct.unpack_from("<3H", raw, position + 28)
        position += 46 + name_size + extra_size + comment_size
        actual_count += 1
        if actual_count > MAX_MEMBERS or position > offset:
            raise ArchiveError("ZIP central member count/size limit exceeded")
    if actual_count != count or position != offset:
        raise ArchiveError("ZIP end record count mismatch")
    return count, start


def _zip_extra(extra):
    offset = 0
    while offset < len(extra):
        if offset + 4 > len(extra):
            raise ArchiveError("truncated ZIP extra field")
        kind, size = struct.unpack_from("<HH", extra, offset)
        offset += 4
        if kind == 1 or offset + size > len(extra):
            raise ArchiveError("ZIP64 or malformed ZIP extra field")
        offset += size


def _zip_payload(raw, info, central_start):
    offset = info.header_offset
    if offset < 0 or offset + 30 > central_start:
        raise ArchiveError("invalid ZIP local header offset")
    fields = struct.unpack_from("<4s5H3L2H", raw, offset)
    signature, _, flags, method, _, _, crc, packed, size, name_length, extra_length = fields
    start = offset + 30 + name_length + extra_length
    end = start + info.compress_size
    if (signature != b"PK\x03\x04" or flags != info.flag_bits or method != info.compress_type
            or end > central_start or start > central_start
            or raw[offset + 30:offset + 30 + name_length] !=
            info.orig_filename.encode("utf-8" if flags & 0x800 else "cp437")):
        raise ArchiveError("ZIP local/central metadata mismatch")
    _zip_extra(raw[offset + 30 + name_length:start])
    expected = (info.CRC, info.compress_size, info.file_size)
    if flags & 8:
        if any(a not in (0, b) for a, b in zip((crc, packed, size), expected)):
            raise ArchiveError("invalid ZIP descriptor local sizes")
        descriptor = end + (4 if raw[end:end + 4] == b"PK\x07\x08" else 0)
        if descriptor + 12 > central_start or struct.unpack_from("<3L", raw, descriptor) != expected:
            raise ArchiveError("invalid ZIP data descriptor")
        end = descriptor + 12
    elif (crc, packed, size) != expected:
        raise ArchiveError("ZIP local/central sizes mismatch")
    compressed = raw[start:start + info.compress_size]
    if method == zipfile.ZIP_STORED:
        data = compressed
    else:
        stream = zlib.decompressobj(-zlib.MAX_WBITS)
        data = stream.decompress(compressed, info.file_size + 1)
        if not stream.eof or stream.unconsumed_tail or stream.unused_data:
            raise ArchiveError("invalid or over-limit ZIP deflate stream")
    if len(data) != info.file_size or zlib.crc32(data) & 0xFFFFFFFF != info.CRC:
        raise ArchiveError("ZIP payload size/CRC mismatch")
    return data, end


def read_zip_safely(raw_bytes):
    """Return regular file payloads from bounded stored/deflated non-ZIP64 ZIP."""
    raw = _raw(raw_bytes)
    expected_count, central_start = _zip_layout(raw)
    files, directories, seen = {}, set(), set()
    total = 0
    intervals = []
    try:
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            members = archive.infolist()
            if len(members) != expected_count or (members and min(m.header_offset for m in members) != 0):
                raise ArchiveError("ZIP central directory count/offset mismatch")
            for info in members:
                if (info.orig_filename != info.filename or info.flag_bits & ~0x80E
                        or info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                        or info.header_offset < 0 or info.header_offset >= central_start):
                    raise ArchiveError("unsupported ZIP member metadata")
                _zip_extra(info.extra)
                mode = info.external_attr >> 16
                kind = stat.S_IFMT(mode)
                directory = info.is_dir()
                if (kind not in (0, stat.S_IFREG, stat.S_IFDIR)
                        or (kind == stat.S_IFDIR and not directory)
                        or (kind == stat.S_IFREG and directory)
                        or (info.external_attr & 0x10 and not directory)):
                    raise ArchiveError("unsupported ZIP member type")
                name = _name(info.orig_filename, directory=directory)
                if name in seen:
                    raise ArchiveError("duplicate ZIP path")
                seen.add(name)
                if directory:
                    if info.file_size:
                        raise ArchiveError("ZIP directory contains a payload")
                    directories.add(name)
                total += info.file_size
                if info.file_size > MAX_FILE_SIZE or total > MAX_TOTAL_SIZE:
                    raise ArchiveError("ZIP payload size limit exceeded")
                data, end = _zip_payload(raw, info, central_start)
                intervals.append((info.header_offset, end))
                if not directory:
                    files[name] = data
    except (zipfile.BadZipFile, NotImplementedError, RuntimeError, UnicodeError, OSError, EOFError, zlib.error) as error:
        raise ArchiveError("invalid ZIP archive") from error
    previous = 0
    for start, end in sorted(intervals):
        if start != previous:
            raise ArchiveError("overlapping or unreferenced ZIP local entries")
        previous = end
    if previous != central_start:
        raise ArchiveError("unreferenced ZIP local data")
    _tree(files, directories)
    return {name: files[name] for name in sorted(files)}


def _decimal(field, base=10):
    try:
        text = field.decode("ascii").rstrip(" ")
        allowed = "01234567" if base == 8 else "0123456789"
        if not text or any(c not in allowed for c in text):
            raise ValueError
        return int(text, base)
    except (UnicodeError, ValueError) as error:
        raise ArchiveError("invalid ar numeric metadata") from error


def _deb_contents(raw):
    raw = _raw(raw)
    if not raw.startswith(b"!<arch>\n"):
        raise ArchiveError("missing normal ar signature")
    members, offset = {}, 8
    for expected in _DEB_NAMES:
        if offset + 60 > len(raw):
            raise ArchiveError("truncated ar header")
        header = raw[offset:offset + 60]
        if header[58:] != b"`\n":
            raise ArchiveError("invalid ar header trailer")
        try:
            name = header[:16].decode("ascii").rstrip(" ")
        except UnicodeError as error:
            raise ArchiveError("invalid ar member name") from error
        if name.endswith("/"):
            name = name[:-1]
        if name != expected:
            raise ArchiveError("Debian requires exactly ordered Debian 2.0 gzip members")
        _decimal(header[16:28])
        _decimal(header[28:34])
        _decimal(header[34:40])
        mode = _decimal(header[40:48], 8)
        if stat.S_IFMT(mode) not in (0, stat.S_IFREG):
            raise ArchiveError("non-regular ar member")
        size = _decimal(header[48:58])
        offset += 60
        if size > MAX_ARCHIVE_SIZE or offset + size > len(raw):
            raise ArchiveError("truncated or over-limit ar payload")
        members[name] = raw[offset:offset + size]
        offset += size
        if size % 2:
            if raw[offset:offset + 1] != b"\n":
                raise ArchiveError("invalid ar alignment padding")
            offset += 1
    if offset != len(raw) or members["debian-binary"] != b"2.0\n":
        raise ArchiveError("unexpected ar tail or Debian version")
    archives = {name: _tar_contents(members[name]) for name in _DEB_NAMES[1:]}
    if sum(len(data) for files, _ in archives.values() for data, _ in files.values()) > MAX_TOTAL_SIZE:
        raise ArchiveError("combined Debian payload size limit exceeded")
    if sum(len(files) + len(dirs) for files, dirs in archives.values()) > MAX_MEMBERS:
        raise ArchiveError("combined Debian member count limit exceeded")
    return members, archives


def read_deb(raw_bytes):
    """Validate strict Debian 2.0 ar and both inner tars; return raw ar members."""
    members, _ = _deb_contents(raw_bytes)
    return members


def canonical_deb(raw_bytes, epoch):
    """Canonicalize a strict gzip Debian package, preserving bytes/execute bits."""
    epoch = _epoch(epoch)
    _, archives = _deb_contents(raw_bytes)
    members = {"debian-binary": b"2.0\n"}
    for name in _DEB_NAMES[1:]:
        files, directories = archives[name]
        members[name] = _tar(files, directories, epoch)
    output = bytearray(b"!<arch>\n")
    for name in _DEB_NAMES:
        data = members[name]
        header = (f"{name + '/':<16}{epoch:<12}{0:<6}{0:<6}{'100644':<8}{len(data):<10}`\n").encode("ascii")
        if len(header) != 60:
            raise ArchiveError("ar field length overflow")
        output.extend(header)
        output.extend(data)
        if len(data) % 2:
            output.extend(b"\n")
    return _raw(bytes(output))
