# ChatGPT X: Theos builds, direct USB installs and device checks (see docs/development.md).
PYTHON ?= python3
PHONE_ARGS ?=
.PHONY: phone phone-build phone-install phone-check phone-doctor phone-screen
phone:
	$(PYTHON) scripts/phone.py deploy $(PHONE_ARGS)
phone-build:
	$(PYTHON) scripts/phone.py build $(PHONE_ARGS)
phone-install:
	$(PYTHON) scripts/phone.py install $(PHONE_ARGS)
phone-check:
	$(PYTHON) scripts/phone.py check $(PHONE_ARGS)
phone-doctor:
	$(PYTHON) scripts/phone.py doctor $(PHONE_ARGS)
phone-screen:
	$(PYTHON) scripts/phone.py screen $(PHONE_ARGS)
.PHONY: phone-restart
phone-restart:
	$(PYTHON) scripts/phone.py restart $(PHONE_ARGS)
.PHONY: toolchain toolchain-doctor
toolchain:
	$(PYTHON) tools/theos/bootstrap.py
toolchain-doctor:
	$(PYTHON) tools/theos/doctor.py
