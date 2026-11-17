// Foundation-only request building for the stage-6 Projects (API6C) and Tasks (API6D) screens:
// exact contract parameters (without operationId: OR6Chat7Write adds it), validation with
// localized problems, and the task editor state (schedule fields ↔ the iCalendar VEVENT the
// service stores, through OR6Chat6TaskSchedule / OR6Chat6TaskScheduleParse). No UIKit, no
// network. Tests: tests/chat-ui6/tasks.m and tests/chat-ui6/projects.m (held provider).
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
#pragma mark Projects (support/priority6c/contracts.json)
// projects.create {name, emoji, theme:null, projectOnly}. name 1…240 after trimming; emoji
// optional ≤64 (empty: null). The theme is never invented: no honest choice list exists.
NSDictionary *OR6Chat6ProjectCreateRequest(NSString *name, NSString *emoji, BOOL projectOnly, NSString **problem);
// projects.update {projectId, name, emoji, theme} from the FRESH projects.detail (API6CProject):
// name/emoji nil = not edited (the fresh value is sent), emoji @"" = removed (null); the theme is
// always the fresh one. nil + problem when invalid, not writable or nothing changed.
NSDictionary *OR6Chat6ProjectUpdateRequest(NSDictionary *fresh, NSString *name, NSString *emoji, NSString **problem);
// projects.instructions.update {projectId, instructions} (≤16000, may be empty) from the fresh
// projects.detail; nil + problem when not writable, too long or unchanged.
NSDictionary *OR6Chat6ProjectInstructionsRequest(NSDictionary *fresh, NSString *instructions, NSString **problem);
// The unresolved-latch key of a project write: "<op>:<projectId>" (create: "<op>:<trimmed lowercased name>").
NSString *OR6Chat6ProjectIntent(NSString *operation, NSString *target);

#pragma mark Tasks (support/priority6d/contracts.json)
// tasks.list base parameters for OR6Chat6Pager (the pager adds cursor): {filter} where filter is
// scheduled | paused | finished, anything else null (all tasks).
NSDictionary *OR6Chat6TaskListParameters(NSString *filter);
// Editor state (mutable; the screen edits its keys and sets scheduleEdited when a schedule field
// changes): title, prompt, timezone (name), timingMode, frequency (once|daily|weekdays|weekly|
// monthly), hour, minute, weekdays (NSNumbers 1 = Monday … 7 = Sunday), monthDay (1…31),
// year/month/day (the date of a one-time run), original (the task's schedule string),
// representable (OR6Chat6TaskScheduleParse understood it), scheduleEdited.
// task nil: a new task (daily 09:00 in `local`, exact_schedule); else the fresh tasks.get task.
NSMutableDictionary *OR6Chat6TaskEditorState(NSDictionary *task, NSDate *now, NSTimeZone *local);
// YES when the schedule fields may be edited: representable and not a condition_watch task.
BOOL OR6Chat6TaskScheduleEditable(NSDictionary *state);
// The first run the edited fields describe (strictly after now for repeating schedules), or nil.
NSDate *OR6Chat6TaskEditorStart(NSDictionary *state, NSDate *now);
// The VEVENT to send: the original string unchanged unless scheduleEdited; else built from the
// fields. nil + problem (no weekday, a one-time run in the past, no valid time zone).
NSString *OR6Chat6TaskEditorSchedule(NSDictionary *state, NSDate *now, NSString **problem);
// tasks.create {task: API6DTaskDraft} (timingMode exact_schedule unless the state says flexible).
NSDictionary *OR6Chat6TaskCreateRequest(NSDictionary *state, NSDate *now, NSString **problem);
// tasks.update {expectedRevision, taskId, task} bound to the fresh task's revision; model, effort,
// emoji, email/notification flags and thread mode are kept from the fresh task.
NSDictionary *OR6Chat6TaskUpdateRequest(NSDictionary *fresh, NSDictionary *state, NSDate *now, NSString **problem);
// tasks.setSchedule {expectedRevision, taskId, schedule, timezone, timingMode}; nil + problem when
// the schedule is not editable or was not changed.
NSDictionary *OR6Chat6TaskSetScheduleRequest(NSDictionary *fresh, NSDictionary *state, NSDate *now, NSString **problem);
// Localized timing mode («Exact time», «Flexible time», «When a condition is met»), nil if unknown.
NSString *OR6Chat6TaskTimingText(id timingMode);
#ifdef __cplusplus
}
#endif
