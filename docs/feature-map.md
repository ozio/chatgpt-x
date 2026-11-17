# Feature map

This is a map, not a roadmap. It lists every user-facing feature of the current
official ChatGPT iOS app (reference: version 1.2026.300) and shows what ChatGPT X
does with each one today. Use it to find open work and to compare behaviour with
the real app (see [CONTRIBUTING](../CONTRIBUTING.md)).

A machine-readable copy is in [feature-map.json](feature-map.json). When you change
what a feature does, update both files in the same commit.

## Status legend

| | Status | Meaning |
|---|---|---|
| ✅ | Native | A native iOS 6 screen is connected and works with a normal ChatGPT session. Some appear only when the service offers the feature to the account. |
| 🟡 | Partial | Part of the flow works natively; the rest is missing or limited. |
| 🌐 | Opens the website | The app hands off to chatgpt.com in Safari. |
| ⚪ | Written, not exposed | Code exists but is hidden in the UI. |
| 🔧 | Client API only | The request layer exists, no screen uses it yet. A good first contribution. |
| ⬜ | Not implemented | Nothing yet. |
| ⛔ | Not possible on iOS 6 | Needs hardware, OS services or frameworks that iOS 6 does not have. |

## Totals

| Status | Features |
|---|---:|
| ✅ Native | 172 |
| 🟡 Partial | 20 |
| 🌐 Opens the website | 14 |
| ⚪ Written, not exposed | 6 |
| 🔧 Client API only | 157 |
| ⬜ Not implemented | 120 |
| ⛔ Not possible on iOS 6 | 38 |
| **All** | **527** |

## Groups

- [Chats, history and messaging](#chats-history-and-messaging) (48)
- [Message input](#message-input) (7)
- [Models, Work and tools](#models-work-and-tools) (46)
- [Search and places](#search-and-places) (7)
- [Tasks and schedules](#tasks-and-schedules) (13)
- [Projects](#projects) (15)
- [Library, Spaces and Sites](#library-spaces-and-sites) (32)
- [GPTs](#gpts) (6)
- [Voice conversations](#voice-conversations) (18)
- [Dictation and read aloud](#dictation-and-read-aloud) (11)
- [Files, camera and documents](#files-camera-and-documents) (17)
- [Images and creativity](#images-and-creativity) (28)
- [System integrations](#system-integrations) (35)
- [Accessibility](#accessibility) (3)
- [Sign-in, sessions and security](#sign-in-sessions-and-security) (39)
- [Workspaces](#workspaces) (5)
- [Subscriptions and limits](#subscriptions-and-limits) (10)
- [Getting started](#getting-started) (4)
- [Settings and personalization](#settings-and-personalization) (16)
- [Memory](#memory) (15)
- [Privacy and data controls](#privacy-and-data-controls) (23)
- [Family, age and support](#family-age-and-support) (17)
- [Shopping, business and ads](#shopping-business-and-ads) (16)
- [Orbit / dot](#orbit--dot) (32)
- [Codex and remote work](#codex-and-remote-work) (38)
- [Health](#health) (12)
- [Finances](#finances) (14)

## Chats, history and messaging

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | New chat | Start a new conversation with ChatGPT. | `chat.new` |
| ✅ | Chat history | Pick a saved conversation from the sidebar and continue it. | `chat.history` |
| ✅ | Rename a conversation | Change the name of an existing conversation. | `chat.rename` |
| ✅ | Archive a chat | Remove a conversation from the main list and keep it in the archive. | `chat.archive` |
| ✅ | Restore from archive | Open the archive and return a conversation to the main list. | `chat.unarchive` |
| ✅ | Delete a chat | Delete the selected conversation. | `chat.delete` |
| ✅ | Pin conversations | Pin or unpin a conversation in navigation. | `chat.pin` |
| ✅ | Temporary chat | Start a conversation that does not appear in regular history. | `chat.temporary` |
| ✅ | Branch a conversation | Continue from a selected message in a new chat. | `chat.branch` |
| ✅ | Edit a sent message | Change your already sent text and continue from it. | `chat.edit_message` |
| ✅ | Retry a failed request | Resend a message after an error, including as a new message. | `chat.retry` |
| ✅ | Copy a response | Copy the response text to the clipboard. | `chat.copy_text` |
| ✅ | Select part of a response | Select part of a message's text for further actions. | `chat.select_text` |
| ✅ | Copy Markdown | Get the response text with Markdown formatting. | `chat.copy_markdown` |
| ✅ | Copy a code block | Copy code from a single code block in a response. | `chat.copy_code` |
| 🔧 | Rate a response | Mark a response as good or bad and send detailed feedback. | `chat.feedback` |
| ✅ | Live response streaming | Read the response while it is still arriving from the server. | `chat.stream` |
| ✅ | Stop generating | Stop the current response. | `chat.stop` |
| ✅ | Continue an unfinished response | Ask the server to continue an interrupted generation. | `chat.continue` |
| 🟡 | Formatted response text | Read Markdown, links and code blocks in messages. | `chat.rich_text` |
| ✅ | Response sources and citations | Open the list of sources a response cites. | `chat.sources` |
| ✅ | Share a conversation link | Create a link that opens a published conversation. | `chat.share_link` |
| ✅ | View a shared conversation | Open a conversation available by link in read-only mode. | `chat.shared_view` |
| ✅ | Delete a shared link | Stop access through a previously created link. | `chat.shared_link_delete` |
| 🔧 | Group conversation | Create a group chat or turn a personal conversation into a group. | `chat.group_create` |
| 🔧 | Invite to a group by link | Send an invite link and join a group through it. | `chat.group_invite` |
| 🔧 | Group members | See the members and invite people to a group conversation. | `chat.group_members` |
| 🔧 | Leave a group conversation | Leave a group or remove it from your list. | `chat.group_leave` |
| 🔧 | Group instructions | Set shared ChatGPT instructions separate from personal instructions. | `chat.group_instructions` |
| 🔧 | Shared group context | Use shared group context kept separate from personal memory. | `chat.group_memory` |
| 🔧 | Pin groups | Pin a group chat, within the pin limit. | `chat.group_pin` |
| 🔧 | Direct messages | Open the direct messages list and continue a conversation with a person. | `chat.dm_inbox` |
| 🔧 | Message requests | View incoming requests, accept them and send invitations. | `chat.dm_requests` |
| 🔧 | Message delivery status | See sending, delivered, seen and error states of a message. | `chat.dm_delivery` |
| 🔧 | ChatGPT in conversations | Ask ChatGPT to respond using the context of a direct or group conversation. | `chat.dm_ask_chatgpt` |
| 🔧 | Message reply threads | Open replies to a message and the related conversation. | `chat.dm_threads` |
| 🔧 | Block a contact | Block and unblock a user, limiting invitations and profile search. | `chat.dm_block` |
| 🔧 | Chat profile | Edit your name, bio and details visible to other participants. | `chat.profile` |
| ✅ | Regenerate a response | Request another version of the response to the same prompt. | `chat.regenerate` |
| 🔧 | React to a message | Add a reaction to a message in a conversation. | `chat.message_reaction` |
| ✅ | Report a conversation | Report conversation content, with a warning about the context shared. | `chat.report` |
| 🔧 | Rename a group | Change the display name of a group conversation. | `chat.group_rename` |
| 🔧 | Reply to a message | Reply to a selected message in a conversation. | `chat.dm_reply` |
| 🔧 | Delete a message | Delete the selected message after confirmation. | `chat.dm_delete_message` |
| ✅ | Lock a conversation | Move a conversation to Locked chats, hiding it from recents and search. | `chat.lock` |
| ✅ | Open locked conversations | Open the Locked chats list after access verification. | `chat.locked_list` |
| ✅ | Unlock a conversation | Return a locked conversation to normal access. | `chat.unlock` |
| ✅ | Locked chats and memory | Do not update shared memory from a locked chat; after unlocking, normal settings apply. | `chat.locked_memory` |

## Message input

| | Feature | What it does | ID |
|---|---|---|---|
| ⚪ | Conversation starters | Pick a suggested topic or ready-made starter prompt. | `compose.suggestions` |
| ⚪ | Input autocomplete | Pick a suggested continuation of the text you are typing. | `compose.autocomplete` |
| ✅ | Full-screen prompt editor | Expand the input field for long text. | `compose.fullscreen` |
| ⚪ | Mention apps and sources | Find a connected tool or source by mentioning it in a prompt. | `compose.mentions` |
| ⚪ | Next prompt prediction in Work | Accept a suggested continuation of a Work prompt. | `compose.work_prediction` |
| ✅ | Send a text message | Send the typed prompt and get a response in the current conversation. | `compose.send` |
| ✅ | Answer clarifying questions | Choose one or more options, type your own answer and move between the model's questions. | `compose.clarifications` |

## Models, Work and tools

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Choose a model and mode | Choose an available model or work mode for the conversation. | `tools.model_picker` |
| ✅ | Reasoning effort | Choose the available depth or duration of the model's reasoning. | `tools.reasoning_effort` |
| ✅ | Model progress | View the status and history of the steps in a request. | `tools.reasoning_status` |
| ✅ | Deep research | Start a research request and follow the asynchronous work. | `tools.deep_research` |
| ✅ | Download research results | Save the generated research document. | `tools.research_export` |
| 🟡 | Data analysis and calculations | Get a calculated result and visualizations inside a response. | `tools.data_analysis` |
| 🔧 | Sandboxed code execution | Open the view of code execution and its result. | `tools.code_execution` |
| 🔧 | Canvas | Open a separate Canvas document or artifact from a response. | `tools.canvas` |
| ✅ | Study mode | Start a learning dialogue in Study and Learn mode. | `tools.study` |
| 🔧 | Review flashcards | Study a deck, flip cards, mark what you know and repeat mistakes. | `tools.flashcards_study` |
| 🔧 | Edit flashcards | Create or fix cards and save the deck. | `tools.flashcards_edit` |
| 🔧 | Browse the whole deck | Open a card grid with filters for learned, missed and unreviewed cards. | `tools.flashcards_grid` |
| ⬜ | Shared quizzes | Open or share an interactive quiz from a conversation. | `tools.shared_quiz` |
| ✅ | Apps and plugins catalog | Browse, search and open cards of connectable apps. | `tools.apps_catalog` |
| ✅ | Install and enable an app | Install a plugin, enable it and try it in chat. | `tools.app_install` |
| ✅ | Remove a connected app | Disable an installed plugin after confirmation. | `tools.app_remove` |
| 🔧 | Sign in to a connected service | Authorize with an external provider and return access to the app. | `tools.connector_auth` |
| 🔧 | Reconnect a service | Sign in again when the service's required permissions have changed. | `tools.connector_reconnect` |
| ✅ | Disconnect a service account | Unlink a connected external provider account. | `tools.connector_disconnect` |
| ✅ | Sync settings and status | Configure a connection and view its status or admin restrictions. | `tools.connector_settings` |
| ✅ | Approve external actions | Allow a specific tool action after reviewing its parameters. | `tools.action_approval` |
| ⚪ | Skills catalog | Open skill details and add or remove a skill for use in chat. | `tools.skills` |
| 🔧 | Interactive app blocks | Open an app's embedded interface inside a response. | `tools.app_blocks` |
| ⬜ | View the cloud browser | Open a live view of a browser running remotely. | `tools.cloud_browser_live` |
| ⬜ | Control the cloud browser | Temporarily take control, type text, navigate and hand execution back. | `tools.cloud_browser_takeover` |
| ⬜ | Cloud browser display mode | Switch between desktop and mobile views and open the snapshot gallery. | `tools.cloud_browser_layout` |
| ⬜ | Site sign-in for tasks | Sign in to a site when a running conversation requests it. | `tools.browser_login` |
| ✅ | Work mode | Enter Work mode to work with tools and materials. | `tools.work_mode` |
| ✅ | Continue a response in Work | Switch from a regular response to Work mode. | `tools.work_handoff` |
| 🔧 | Text editor for responses | Edit prepared text and request changes. | `tools.writing_editor` |
| ✅ | Email draft in a response | Edit the sender, recipients and copies of a prepared email. | `tools.email_draft` |
| 🔧 | Send a prepared email | Send the email through a connected provider or open it in a mail client; undo sending where supported. | `tools.email_send` |
| 🔧 | College application plan | Create a college application plan and view its overview. | `tools.college_plan` |
| 🔧 | List of schools | Add and remove schools, and open descriptions, costs and deadlines. | `tools.college_schools` |
| 🔧 | Application tasks | Add and edit tasks with dates, mark them done and see progress. | `tools.college_tasks` |
| 🔧 | Application timeline | View deadlines and upcoming application stages. | `tools.college_timeline` |
| 🔧 | Regular plan updates | Schedule updates and continue discussing the plan in chat. | `tools.college_updates` |
| ✅ | Model version | Choose an available version of a model family. | `tools.model_version` |
| ✅ | Automatic deeper reasoning | Allow automatic switching to deeper reasoning for a hard question. | `tools.model_auto_switch` |
| 🔧 | Delete a college plan | Delete the whole plan with its chats, schools and tasks; materials saved in Library stay there. | `tools.college_delete` |
| ✅ | Text translation | Type or paste text and get a translation in a separate block or screen. | `tools.translate` |
| ✅ | Translation languages | Choose the target language and swap languages. | `tools.translate_language` |
| ✅ | Copy and share a translation | Copy or share the translated text. | `tools.translate_share` |
| 🔧 | Rate a translation | Send positive or negative feedback on a translation, or turn this block off for yourself. | `tools.translate_feedback` |
| 🔧 | Language learning block | See a phrase's translation and pronunciation in a special response block. | `tools.language_block` |
| 🔧 | Add a phrase to flashcards | Save a phrase from the language block to flashcards and open the deck. | `tools.language_flashcards` |

## Search and places

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Search chat history | Find a conversation in saved history. | `search.history` |
| ✅ | Global content search | Search available chats, projects and other items in the app. | `search.global` |
| ✅ | Web search | Run a web search from a conversation and get a response with sources found. | `search.web` |
| 🔧 | Place cards and bookings | Open a found place's card and go to booking if offered. | `search.places` |
| ⬜ | Explore feed | Open the Explore Feed and pick an item to discuss further. | `search.explore_feed` |
| 🔧 | Map of found places | Open a full-screen map of results, center it and apply filters. | `search.places_map` |
| 🔧 | Follow-up about a place | Send a follow-up question about a specific point on the map. | `search.places_followup` |

## Tasks and schedules

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Scheduled tasks list | View active, completed and paused tasks. | `tasks.list` |
| ✅ | Create a task | Create a scheduled task with a name and instructions. | `tasks.create` |
| ✅ | Edit a task | Change the name, prompt and settings of an existing task. | `tasks.edit` |
| ✅ | Set a schedule | Choose date, time, flexible time of day and repeats: hours, days, weeks, months, years. | `tasks.schedule` |
| ✅ | Pause and resume | Pause a task or turn its execution back on. | `tasks.pause_resume` |
| ✅ | Run a task now | Run a scheduled task immediately. | `tasks.run_now` |
| ✅ | Delete a task | Delete a scheduled task. | `tasks.delete` |
| 🔧 | Completion notification | Choose a notification for when a task finishes. | `tasks.notify` |
| ⬜ | Event-triggered task | Set up an event or webhook trigger and manually process accumulated events. | `tasks.webhook` |
| 🔧 | Goals and routines | Create a goal and view progress, instructions and related files. | `tasks.goals` |
| 🔧 | Routines on the home screen | Open an overview of recurring tasks and goals. | `tasks.routines` |
| 🔧 | Task plan and steps | View the plan with completed, current and pending steps, and open the result chat. | `tasks.plan` |
| 🔧 | Share tasks by link | Share a task, or save and enable an imported task. | `tasks.share_import` |

## Projects

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Projects list and search | Open projects, search by name and pick a project. | `projects.list` |
| ✅ | Create a project | Create a project for conversations and shared sources. | `projects.create` |
| ✅ | Project name and appearance | Change the name and appearance of an existing project. | `projects.edit` |
| ✅ | Delete a project | Delete a project with its contents, after warning about losing chats and files. | `projects.delete` |
| ✅ | Project instructions | Set the style and topical context for all of a project's conversations. | `projects.instructions` |
| ✅ | New chat in a project | Start a conversation with the selected project's context. | `projects.chat` |
| 🟡 | Move a chat to a project | Add an existing conversation to a project or remove it from one. | `projects.move_chat` |
| 🟡 | Project memory | Choose default or isolated project memory, if the server allows. | `projects.memory` |
| 🟡 | Project sources | View, add or remove files used by all of a project's chats. | `projects.files` |
| 🔧 | Linked project sources | Add materials from Library, a Space or connected apps. | `projects.source_links` |
| 🔧 | Create a text source | Create text material directly as a project source. | `projects.text_source` |
| 🔧 | Share a project | Share a project and manage participant access. | `projects.share` |
| 🔧 | Sharing source warnings | Before sharing, show which linked sources participants will receive. | `projects.share_warnings` |
| 🔧 | Join a shared project | Accept an invitation and open a project you were given access to. | `projects.join` |
| 🔧 | Leave a shared project | Leave a shared project and optionally keep a copy of your chats. | `projects.leave` |

## Library, Spaces and Sites

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Browse Library files | Open the shared library and browse files and saved materials. | `library.browse` |
| ✅ | Library filters and layout | Filter contents and choose list or grid view. | `library.filter_sort_layout` |
| ✅ | Search the library | Find a file or material in Library. | `library.search` |
| ⚪ | Add materials to a prompt | Choose library files or a folder as conversation context. | `library.attach` |
| ✅ | Create folders | Create a folder for library materials. | `library.folders` |
| ✅ | Move materials | Move selected files or folders to another folder. | `library.move` |
| ✅ | Rename files and folders | Change the name of a material or folder. | `library.rename` |
| ✅ | Library trash | Move a material to recently deleted, with a warning about project links. | `library.delete` |
| ✅ | Restore from trash | Bring back a previously deleted file. | `library.restore` |
| ✅ | Delete permanently and empty trash | Permanently delete a selected material or everything in the trash. | `library.delete_forever` |
| 🔧 | Create and edit a note | Create a note and edit its Markdown content. | `library.note` |
| 🔧 | Version history | Open earlier versions and restore a selected one. | `library.versions` |
| ✅ | Files in a conversation | Open a separate list of files linked to a chat. | `library.conversation_files` |
| 🟡 | Save items to favorites | Save responses, places, products and other items and find them by type. | `library.favorite` |
| ✅ | Favorites folders | Create a favorites folder, add material and move it between folders. | `library.favorite_folders` |
| 🔧 | Share library materials | Grant access to a material, choose a role and remove your own access. | `library.share` |
| ✅ | Automatic Library search | Allow the model to find library materials for a response. | `library.auto_context` |
| ✅ | Connected storage files | Browse materials from a connected provider, including Google Drive. | `library.mounted_sources` |
| ⬜ | Spaces and pages | Browse spaces, pages and subpages. | `library.spaces_browse` |
| ⬜ | Edit a page | Change the content and formatting of a document or page. | `library.spaces_edit` |
| ⬜ | Discuss a page or slides | Send a prompt with the context of the current page or a single slide. | `library.spaces_chat` |
| 🔧 | Page roles and inherited access | Grant view, comment or edit rights, accounting for access via a parent page or space. | `library.spaces_sharing` |
| 🔧 | Request page access | Ask for access and check the result; the owner can review the request. | `library.spaces_request_access` |
| 🔧 | Spaces activity and mentions | View updates and mentions in pages, filter unread and mark all as read. | `library.spaces_activity` |
| ⬜ | Create a site | Create a site from a text description in the app. | `library.sites_create` |
| ⬜ | Site preview | Open an interactive view of the site being created. | `library.sites_preview` |
| ⬜ | Edit a site via chat | Ask to change the site or a specific project file. | `library.sites_edit` |
| ⬜ | Site sharing | See who can access a site and choose private, group, workspace or public access. | `library.sites_access` |
| ⬜ | Site visit statistics | Open page views and visitor counts for a chosen period. | `library.sites_analytics` |
| ⬜ | Publish a site | Publish a site and see publishing, preparing or paused states. | `library.sites_publish` |
| ⬜ | Custom site domain | Open domain settings, DNS records and connection status. | `library.sites_domain` |
| ⬜ | Site variables and secrets | Configure environment variables and secrets for a site project. | `library.sites_environment` |

## GPTs

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | GPT catalog | Browse collections and categories of public GPTs. | `gpts.explore` |
| ✅ | Search GPTs | Find a public GPT by query. | `gpts.search` |
| ✅ | GPT details | Read the description and open a conversation with the selected GPT. | `gpts.detail` |
| ✅ | My GPTs | Open the list of GPTs owned by the account. | `gpts.personal` |
| ⬜ | GPT action accounts | View and connect accounts required by a GPT's actions. | `gpts.action_accounts` |
| 🟡 | GPT action settings | Open the integration action settings of a specific GPT. | `gpts.action_permissions` |

## Voice conversations

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Voice conversation | Start a two-way voice conversation from a regular chat. | `voice.conversation` |
| ✅ | Interrupt a voice response | Stop a spoken response with a tap; the interface also describes natural interruptions. | `voice.interrupt` |
| ✅ | Microphone and sound controls | Mute and unmute the microphone; separately mute ChatGPT's audio. | `voice.mute` |
| ✅ | End a call | End the current voice conversation and return to chat. | `voice.end` |
| ✅ | Resume a voice conversation | Call resumption is tracked in the code; the exact user trigger and guarantees are not established. | `voice.resume` |
| ✅ | Choose a voice | Preview and choose an available voice in onboarding and call settings. | `voice.choose_voice` |
| ✅ | Choose a voice mode or model | Choose Standard, Advanced or Live from the options available in this build. | `voice.choose_model` |
| ⬜ | Voice model for video and screen | Offer the previous voice model if the selected one does not support live video or screen sharing. | `voice.model_fallback` |
| ✅ | Voice conversation language | Choose a language or automatic detection during a call. | `voice.language` |
| ✅ | Voice conversation transcript | Show and hide the transcript in the voice interface. | `voice.transcript` |
| ⬜ | Voice with the screen locked | Keep talking after the phone locks when background mode is on. | `voice.background` |
| 🔧 | Start Voice automatically | Open Voice when ChatGPT launches, per the user's setting. | `voice.start_on_open` |
| ⬜ | Raise phone to ear | Start Voice or a dot call by raising the phone to your ear. | `voice.raise_to_ear` |
| ⬜ | Camera video during Voice | Share the live camera image in a voice conversation; switch front and back cameras. | `voice.live_camera` |
| ⛔ | Screen sharing in Voice | Share the screen from a separate broadcast upload extension. | `voice.screen_sharing` |
| 🔧 | Rate a voice call | After a call, rate quality, intelligence, naturalness, interruptions and connection. | `voice.call_feedback` |
| ✅ | Voice limits and basic model | Show that voice time is used up, when it resets, and offer the basic model or a plan change. | `voice.usage_limits` |
| ✅ | Voice connection states | Show waiting for connection, poor network and recovery, without presenting them as a ready conversation. | `voice.connection_recovery` |

## Dictation and read aloud

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Dictate a message | Record speech with the microphone and turn it into input text. | `audio.dictation` |
| ✅ | Stop or cancel dictation | Stop recording for transcription or discard an unfinished dictation. | `audio.dictation_cancel` |
| 🟡 | Live dictation text | Show or hide text as it is recorded in the streaming dictation variant. | `audio.dictation_streaming` |
| ✅ | Transcription failure and retry | Handle a transcription error and the retry or fallback the policy provides. | `audio.dictation_retry` |
| ⬜ | Dictation history | View recent recordings, copy a transcript and export audio. | `audio.dictation_history` |
| 🔧 | Dictation dictionary | Add words and phrases for recognition, and search or delete dictionary entries. | `audio.dictation_dictionary` |
| 🔧 | On-device transcription | An on-device transcription option is provided, with a check of the language and installed language resources. | `audio.local_transcription` |
| ⬜ | Dictation research feedback | The package has a form to rate dictation and send audio with a transcript to the research team. | `audio.dictation_feedback` |
| ✅ | Read a response aloud | Read a text response aloud with a network audio player. | `audio.read_aloud` |
| ✅ | Playback controls | Pause audio, retry after a failure and change speed. | `audio.playback_controls` |
| 🔧 | Pronunciation and learning audio | Play pronunciation and change speed in language blocks and flashcards. | `audio.pronunciation` |

## Files, camera and documents

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Take a photo for a message | Take a photo with the built-in camera and attach it to a message. | `media.camera_photo` |
| ✅ | Photos from the library | Choose one or more photos from the photo library and attach them to a chat. | `media.photo_picker` |
| 🔧 | Recent photo by the input field | Attach a suggested recent photo; separately request access to recent photos. | `media.recent_photo` |
| 🔧 | Annotate a photo | Draw notes on a picture before using it further. | `media.annotate_photo` |
| 🔧 | Record video | Hold the camera button to record video and attach the result. | `media.capture_video` |
| 🔧 | Preview and save video | Play a video, scrub through it and save it to Photos. | `media.preview_video` |
| 🔧 | Audio attachment from a recording | Record an audio attachment in the input field; it differs from dictation to text. | `media.record_audio_attachment` |
| 🔧 | Play an audio attachment | Listen to recorded or received audio and remove the attachment before sending. | `media.audio_attachment_playback` |
| 🟡 | Upload files | Attach a file; track upload and processing, and see an error or limit. | `media.file_upload` |
| 🟡 | Remove or replace an attachment | Remove a selected item or confirm replacing the current attachment. | `media.attachment_remove_replace` |
| ✅ | Attachment limits | Show that the current model blocks uploads, attachments are used up, or the daily quota is reached. | `media.attachment_constraints` |
| ✅ | Unavailable or expired file | Explain that availability has expired and offer to upload the file again. | `media.file_expiry` |
| ✅ | Download a result | Download a file from a response and handle a network failure. | `media.download_file` |
| 🔧 | Scan pages with the camera | Capture a sequence of pages and finish scanning into a document. | `media.document_scan` |
| 🔧 | Edit scanned pages | View, retake, rotate, delete and reorder individual pages. | `media.scan_page_edit` |
| 🔧 | PDF from a scan | Assemble a scan into a PDF, respect the maximum size and keep pages if export fails. | `media.scan_pdf_export` |
| ✅ | Discard an unfinished scan | Warn about losing captured pages when leaving without saving. | `media.scan_discard` |

## Images and creativity

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Create an image | Request image generation and see its progress in the conversation. | `images.create` |
| 🔧 | Multiple images | Show generation of several images at once and their progress. | `images.batch` |
| ✅ | Created images library | Open a grid of previously created images and go to the viewer. | `images.library` |
| ✅ | Full-screen image viewer | Open an image in a lightbox or gallery with zoom and source. | `images.gallery` |
| ✅ | Save and share images | Download one or all images to Photos and open system sharing. | `images.save_share` |
| ⬜ | Download without logo | A separate download-without-logo option is provided, with an offer to change plan. | `images.download_without_logo` |
| 🔧 | Edit an image by prompt | Describe general changes for the selected image. | `images.edit_general` |
| 🔧 | Precise image notes | Place notes on specific points or areas and remove all notes. | `images.edit_precise_notes` |
| 🔧 | Remove an image area | Paint over an area that should be removed. | `images.remove_area` |
| 🔧 | Resize an image | Choose the Resize action in the image viewer. | `images.resize` |
| 🔧 | Sketch as input | Draw a sketch with a pen or eraser, and choose a color and shapes. | `images.sketch` |
| 🔧 | Generation templates and styles | Start from a template, change the illustration style and the subject source: description or attached photos. | `images.templates` |
| 🔧 | Image ideas and trends | Open suggested image ideas, including the Trending tab. | `images.suggestions` |
| ⬜ | Save a reference | Save a selected photo as a named, selectable reference for future images. | `images.reference_save` |
| ⬜ | Manage references | Open the references list; add, edit, replace and delete. | `images.reference_manage` |
| 🔧 | Recreate an image with a reference | Recreate an image with a selected reference and show its attribution. | `images.reference_recreate` |
| ⬜ | Personal face and full-body photos | Add, replace or delete face and full-body photos for results that look like you. | `images.likeness` |
| 🔧 | Share an image prompt template | Prepare a publicly available prompt template, edit its title and text, and pass the publishing eligibility check. | `images.prompt_share` |
| ⬜ | Create a GIF | The package provides states for generating one or several GIFs. | `images.gif_generation` |
| ⬜ | GIF and frames viewer | Play or pause a GIF, change speed, and see the timeline and frame sheet. | `images.gif_viewer` |
| ⬜ | Save and link a GIF | Download a GIF or send a link, with a warning that anyone with the link can view it. | `images.gif_save_share` |
| ⬜ | Create a video (candidate) | The catalog has Create video, with separate free and paid allowances and video credits. | `images.video_generation_candidate` |
| 🔧 | Deferred image or GIF generation | At a limit, queue generation for later and see queued, running, success, expired or error states. | `images.deferred_generation` |
| 🔧 | Ready and limit reset notification | Subscribe to a notification when generation finishes or the image limit resets. | `images.generation_notifications` |
| ⬜ | Game while generating | Play the provided animation or snake game while an image is created. | `images.waiting_game` |
| ⬜ | Create stickers | Choose up to eight emoji and a custom style to generate stickers. | `images.sticker_create` |
| ⬜ | Save stickers | Select several stickers and save them to Photos. | `images.sticker_save` |
| ⬜ | WhatsApp sticker pack | Name a pack and export it to WhatsApp, with a minimum count limit. | `images.sticker_whatsapp` |

## System integrations

| | Feature | What it does | ID |
|---|---|---|---|
| ⛔ | Siri and Shortcuts: ask | Send a prompt through AskIntent, get a response and optionally continue the same conversation. | `integration.siri_ask` |
| ⛔ | Shortcuts: new chat and dictation | Open a new or temporary conversation with an initial action, including dictation or search. | `integration.siri_start_chat` |
| ⛔ | Siri and Shortcuts: Voice | Start a voice conversation through the declared OpenVoiceModeIntent. | `integration.siri_voice` |
| ⛔ | Shortcuts: image and prompt | Pass an image to choose an action, or an image together with a prompt. | `integration.siri_images` |
| ⛔ | Shortcuts: open a project or chat | Open a specific project and start a new chat in it from a system command. | `integration.siri_project` |
| ⛔ | Shortcuts: open dot or message it | Choose a dot or mode and send content through the declared dot intents. | `integration.siri_dot` |
| ⛔ | Shortcuts: Codex, Remote and Work | Intents are provided for opening Codex or a task, plus hidden launch actions for Work and Remote Voice. | `integration.siri_codex_work` |
| ⛔ | App icon quick actions | The build highlights Home Screen shortcuts for quick access to chat, dictation or voice. | `integration.home_quick_actions` |
| ⛔ | ChatGPT shortcut buttons widget | Set up four quick buttons and labels for ChatGPT, Work and Remote. | `integration.widgets_shortcuts` |
| ⛔ | New chat and Voice widgets | Quickly open a regular or temporary chat, dictation or Voice from a modern widget. | `integration.widgets_chat_voice` |
| ⛔ | dot widget | Show dot, unread messages and text, dictation and call buttons. | `integration.widgets_dot` |
| ⛔ | Codex and usage widgets | Show recent tasks for chosen hosts and remaining usage and reset time. | `integration.widgets_codex` |
| ⛔ | Voice call Live Activity | Show Voice status on a system live surface and pass control commands. | `integration.live_activity_voice` |
| ⛔ | Work and dot Live Activity | Show task progress and dot call status on a system live surface. | `integration.live_activity_work_dot` |
| ⛔ | CarPlay: voice conversation | Start Voice and control sound and connection state through a CarPlay scene. | `integration.carplay_voice` |
| ⛔ | CarPlay: chats, projects, remote and dot | Show pinned and recent chats, projects, Remote connections and Work, Codex and dot entry points. | `integration.carplay_navigation` |
| ⛔ | CarPlay settings | Start Voice automatically in CarPlay and hide recent conversations and projects. | `integration.carplay_preferences` |
| ⛔ | Receive from the Share menu | Accept material from another app and open it in ChatGPT. | `integration.share_extension` |
| ⛔ | Ask ChatGPT action in other content | Run an action on selected material or a single photo for touch-up from the system action extension. | `integration.action_extension` |
| ⛔ | ChatGPT stickers in iMessage | Add created stickers to iMessage and send them through the Messages extension. | `integration.imessage_stickers` |
| ⛔ | ChatGPT Search from Safari | An extension redirects a Safari or Google search query to ChatGPT Search. | `integration.safari_search` |
| ⛔ | Exclude a query from Safari redirect | The !g prefix keeps a query in Google; the normalized query is remembered in the exclusion set. | `integration.safari_google_escape` |
| ✅ | Open the app by link | Accept the chatgpt, openai, com.openai.chat and codex schemes and go to the supported destinations. | `integration.url_routes` |
| ⛔ | Hand off a conversation between devices | A conversation user activity type and handoff manager exist; the exact handoff of drafts and state needs separate review. | `integration.handoff` |
| ⛔ | Find projects in system search | The code indexes projects and handles a selected system result. | `integration.project_spotlight` |
| ⬜ | Push notifications and tap-through | Register for notifications, set the badge count and open messages or results from them. | `integration.push_notifications` |
| ⛔ | Rich push handling | Process messages and media attachments in the notification service extension. | `integration.rich_notifications` |
| 🔧 | Local response-ready notification | The code provides local notifications for conversations and waits the user left unfinished. | `integration.local_completion_notifications` |
| 🔧 | Read Apple Calendar | On request, get device events and upcoming meetings with a separate read permission. | `integration.calendar_read` |
| 🔧 | Create an Apple Calendar event | Create an event on the device and open it in Calendar; read and create are permitted separately. | `integration.calendar_create` |
| 🔧 | Read Apple Reminders | Get the device's reminder lists and upcoming or today's reminders. | `integration.reminders_read` |
| 🔧 | Create reminders and lists | Create one or more reminders or a list and open Reminders. | `integration.reminders_create` |
| ⬜ | Search Apple Contacts | Find a person and contact details with address book read permission. | `integration.contacts_read` |
| ⬜ | Add, change and delete contacts | Create, change or delete contacts through approved actions and open the card. | `integration.contacts_mutate` |
| 🔧 | Location for responses | With permission, share location for more relevant responses, show when it is unavailable and manage accuracy. | `integration.location` |

## Accessibility

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Accessible response text and links | Markdown blocks, links and tables have separate accessibility elements and announcements. | `accessibility.voiceover_messages` |
| ✅ | Accessible media and drawing actions | Announce loading states, pages, recording and game controls through accessibility labels and actions. | `accessibility.controls` |
| ✅ | Large text support | Reflection fields have Dynamic Type and accessibility-size variants; full support is not proven. | `accessibility.large_text` |

## Sign-in, sessions and security

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Sign in with email and password | Enter email and password, show or hide the password and continue signing in. | `account.login.email_password` |
| ✅ | Sign in with Google | Choose Google and complete the external sign-in provider. | `account.login.google` |
| ⛔ | Sign in with Apple | Choose Apple as the sign-in provider. | `account.login.apple` |
| 🌐 | Phone sign-in or sign-up | Choose phone, country and a verification code. | `account.login.phone` |
| 🌐 | Sign in with an emailed code | Choose code sign-in and request the email again, with a countdown, if needed. | `account.login.email_code` |
| 🌐 | Password recovery | Request a reset and set a new password. | `account.login.password_reset` |
| 🌐 | Create an account | Register an account and fill in name and date of birth or age. | `account.signup` |
| 🔧 | Continue without an account | Skip sign-in and use the limited guest interface. | `account.guest` |
| ⛔ | Sign in with a passkey | Choose a passkey, including sign-in without entering a name first. | `account.login.passkey` |
| ✅ | Authenticator app code | After the first factor, enter the current six-digit code. | `account.mfa.authenticator` |
| 🌐 | Approve sign-in on another device | Wait for approval in another ChatGPT instance, match the number, resend the request or choose email. | `account.mfa.push_approval` |
| 🌐 | Sign in with a recovery code | Use a saved recovery code as a way to verify. | `account.mfa.recovery_code` |
| ⛔ | Passkey as second factor | Confirm the second factor with an available passkey. | `account.mfa.passkey` |
| ✅ | Cancel and retry sign-in | Close a started sign-in or start over after it expires or is rejected. | `account.login.cancel_retry` |
| 🔧 | Add another account | Add an account without mixing its state with the current one. | `account.switch.add` |
| 🔧 | Switch accounts | Choose another saved account. | `account.switch.select` |
| ✅ | Sign out | Confirm signing out and clearing the related local context. | `account.logout` |
| ✅ | Restore session at launch | Load saved credentials and restore the selected user; if impossible, offer a new sign-in. | `account.session.restore` |
| ✅ | Renew credentials | Refresh authorization data and handle session expiry. | `account.session.renew` |
| 🔧 | Deactivated account screen | Show that the account is unavailable and the next steps available. | `account.deactivated` |
| ⬜ | Link ChatGPT to an external context | Confirm linking a ChatGPT account through a separate linking sheet. | `account.link_external` |
| 🌐 | Re-confirm before changes | Sign in again for a sensitive settings change. | `account.security.reauth` |
| 🌐 | Change password | Set and confirm a new account password. | `account.security.password_change` |
| 🌐 | Change email | Update the account's email address. | `account.security.email_change` |
| ✅ | Add or remove authenticator MFA | Set up an app via QR or secret and verify the code; remove a factor or turn MFA off. | `account.security.mfa_setup` |
| 🔧 | Add SMS MFA and backup phone | Verify a number and enable SMS, including as a backup for the authenticator app. | `account.security.mfa_sms` |
| ⛔ | Create a passkey or security key | Add a new phishing-resistant way to sign in. | `account.security.passkey_add` |
| 🔧 | List and delete passkeys | View active keys and creation dates and delete a selected one. | `account.security.passkey_manage` |
| 🔧 | Advanced account protection | View status and go to Advanced Account Security management. | `account.security.advanced` |
| 🔧 | Security activity log | View sign-ins, factor changes, and event times and locations. | `account.security.history` |
| 🔧 | Security recommendations | See suggestions to add email, passkey or SMS and review sessions. | `account.security.recommendations` |
| ✅ | Sessions and trusted devices | View active devices and tell the current session from a trusted device. | `account.sessions.list` |
| ✅ | Sign out a selected device | Revoke a selected session or remove a trusted device along with its push-approval right. | `account.sessions.revoke` |
| ✅ | Sign out on all devices | Confirm revoking all sessions, including the current one. | `account.sessions.revoke_all` |
| ⬜ | Approve a sign-in request | Approve or deny an incoming ChatGPT sign-in request. | `account.security.incoming_approval` |
| ⬜ | Microsoft and Intune sign-in | Complete Microsoft sign-in; in a managed Intune context, handle the single-allowed-provider requirement. | `account.login.microsoft` |
| ⬜ | Push as a verification method | Manage sign-in requests on already signed-in trusted devices. | `account.security.push_factor` |
| 🌐 | Recover access after losing MFA | Go to an account recovery option when the second factor is unavailable. | `account.security.recovery` |
| ✅ | MFA settings unavailable under Advanced Security | Show that regular MFA settings depend on enhanced protection. | `account.security.mfa_policy` |

## Workspaces

| | Feature | What it does | ID |
|---|---|---|---|
| 🔧 | Choose a workspace | After sign-in, choose a workspace and switch later in settings. | `workspace.select` |
| 🔧 | Create a personal workspace | Create a free personal space for this email. | `workspace.personal_create` |
| ⬜ | Corporate SSO | Sign in again through the required SSO to access a workspace and handle a provider mismatch. | `workspace.sso` |
| 🔧 | Workspace members and management | Open workspace management and the member list. | `workspace.manage` |
| 🔧 | Admin restrictions and workspace disabled | Show features disabled by the admin, deactivation and switching to another workspace. | `workspace.policy_restrictions` |

## Subscriptions and limits

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | View and compare plans | Show Free, Go, Plus and Pro and the differences in offered features. | `subscription.plans` |
| ⬜ | Buy or upgrade via Apple | Choose a subscription and complete payment through the offered Apple checkout. | `subscription.apple_purchase` |
| 🔧 | Buy or upgrade on the web | Open the offered web checkout or go to the website to change a plan. | `subscription.web_purchase` |
| ⬜ | Restore purchases | Restore an already paid entitlement and handle an Apple ID linked to another ChatGPT account. | `subscription.restore` |
| 🔧 | Manage or cancel a subscription | Go to where it was purchased; warn that a subscription from another platform can't be changed in the app. | `subscription.manage_cancel` |
| 🔧 | Payment errors and keeping access | Show a charge failure, a prompt to update the payment method and the workspace restriction deadline. | `subscription.billing_failure` |
| 🔧 | Trials and personal offers | Show limited Plus access, time remaining, what happens after it ends and an available offer. | `subscription.trials_offers` |
| ⬜ | Student offer | Open the special student offer and its intro screen. | `subscription.student_offer` |
| ⬜ | Credits and extra access | Show the credit balance and offer a purchase for extended use. | `subscription.credits_balance_purchase` |
| 🔧 | One-time limit reset | Use an available reset for the 5-hour, weekly or overall limit, with confirmation. | `subscription.usage_reset` |

## Getting started

| | Feature | What it does | ID |
|---|---|---|---|
| 🔧 | Tour after getting a plan | Walk through Plus, Pro, trial or student features, then open the relevant flow. | `onboarding.paid_features` |
| 🔧 | Personalized starting conversation | Offer initial questions about goals and starter prompts. | `onboarding.guided_conversation` |
| 🔧 | Choose theme and voice in onboarding | Choose color, light or dark mode and voice in a step-by-step tour. | `onboarding.theme_voice` |
| 🔧 | Teen introduction to features | Show teen safeguards, starter learning and visual scenarios and the age verification path. | `onboarding.teen` |

## Settings and personalization

| | Feature | What it does | ID |
|---|---|---|---|
| 🟡 | Custom instructions | Edit notes about you and how ChatGPT should behave; apply them to later chats. | `preferences.instructions` |
| 🟡 | Personalization profile | Set nickname, occupation, and interests or values for responses. | `preferences.profile` |
| 🟡 | Base style and tone | Choose a personality and base response style. | `preferences.personality` |
| 🟡 | Response characteristics | Adjust characteristics and reset them to defaults. | `preferences.characteristics` |
| 🔧 | Visual answers and simple view | Choose how visual answers are shown and a simplified layout. | `preferences.visual_answers` |
| ✅ | Automatic web search | Configure the use of web search. | `preferences.auto_web_search` |
| ✅ | Image generation setting | Open the user's Image generation setting. | `preferences.image_creation` |
| ✅ | Appearance theme | Choose a light, dark or system interface. | `preferences.appearance` |
| 🔧 | Accent color | Choose the appearance color. | `preferences.accent` |
| ✅ | App language | Choose the interface language independently of the voice language. | `preferences.language` |
| ⬜ | Haptic feedback | Turn feedback on actions on or off. | `preferences.haptics` |
| 🔧 | Start screen | Choose the screen shown when ChatGPT opens. | `preferences.start_screen` |
| 🔧 | Text autocorrect | Manage autocorrection while typing. | `preferences.spelling` |
| 🔧 | Notification categories | Open notification settings and available categories. | `preferences.notifications` |
| ✅ | Device storage and clearing cache | See the size of cached images and previews and clear temporary data, keeping chats and Library files. | `preferences.cache_storage` |
| 🔧 | Help and about | Open Help Center and FAQ, terms, privacy policy and the version number. | `preferences.help_about` |

## Memory

| | Feature | What it does | ID |
|---|---|---|---|
| 🟡 | Saved memory | Allow ChatGPT to save and use memories. | `memory.enable` |
| 🟡 | Reference chat history | Separately allow referring to past chats when preparing responses. | `memory.history_reference` |
| ⬜ | Browser memory | Configure the use of browser memories. | `memory.browser_reference` |
| ✅ | List and search saved memories | Open saved memories, search and filter entries. | `memory.legacy_list_search` |
| ✅ | Delete a memory | Delete a selected memory entry. | `memory.delete_one` |
| ✅ | Delete all memories | Clear the whole saved memories list after confirmation. | `memory.delete_all` |
| ✅ | Priority and automatic management | Mark important memories and choose automatic memory management. | `memory.priority` |
| ✅ | Memory capacity status | Show that memory is full and offer to delete entries or extend access. | `memory.capacity` |
| 🔧 | Memory summary | Open the automatically maintained memory summary, with a note that the list may be incomplete. | `memory.summary` |
| 🔧 | Refresh the memory summary | Request an update or regeneration of the summary. | `memory.summary_refresh` |
| 🔧 | Correct the memory summary | Select part of the summary or send a text correction. | `memory.summary_correct` |
| 🔧 | Delete and turn off new memory | Delete memory and turn off further remembering in one action, handling partial success. | `memory.summary_clear_disable` |
| 🔧 | Switch between new and old memory | Try the improved memory or return to legacy saved memories. | `memory.experience_switch` |
| ✅ | Memory sources in a response | Understand which memory, past chat or custom instructions influenced a response. | `memory.citations` |
| ✅ | Feedback on memory used | Mark relevance, make a correction or ask to stop mentioning a fact. | `memory.citation_feedback` |

## Privacy and data controls

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Privacy center | Open explanations and links for managing data, memory and account protection. | `privacy.center` |
| 🟡 | Use chats to improve models | Turn sharing of future conversations to improve models on or off. | `privacy.training.text` |
| 🟡 | Audio and video training | Manage separate consent to use Voice recordings for training. | `privacy.training.audio_video` |
| 🌐 | Export account data | Request an archive of history and other data and get a link when ready. | `privacy.export` |
| 🌐 | Delete account | Confirm irreversible account deletion, noting that in-app purchases are cancelled separately. | `privacy.delete_account` |
| 🌐 | Privacy Portal and data requests | Go to the privacy policy, Privacy Portal or data help. | `privacy.requests_help` |
| ✅ | Precise location controls | Open Location Services in Data Controls and learn when precise location is used. | `privacy.location_controls` |
| ✅ | Apps with contact info access | See apps allowed to access contact information and revoke permission. | `privacy.apps_access` |
| ✅ | Connected app read and action permissions | Choose always ask, allow reading, low-risk or all actions; restore the default. | `privacy.apps_permissions` |
| ⬜ | Cloud browser access rules | Set a general confirmation mode and per-site overrides, including blocking. | `privacy.cloud_browser_permissions` |
| ⬜ | Cloud browser verification codes | Choose whether to be asked before a code from connected email is filled in. | `privacy.cloud_browser_email_codes` |
| ⬜ | Clear cloud browser cookies | View sites with cookies and delete one site or all cloud browser cookies. | `privacy.cloud_browser_cookies` |
| ⬜ | Lockdown mode | Restrict external connections: browser, connectors, Deep Research, shopping, downloads and some code; allow a per-chat exception. | `privacy.lockdown` |
| ✅ | Account PIN for locked chats | Create a four-digit PIN and confirm it. | `privacy.locked_pin_create` |
| ✅ | Change Account PIN | Enter the current PIN and set a new one. | `privacy.locked_pin_change` |
| 🌐 | Reset PIN and delete locked chats | Confirm losing everything protected by the old PIN when resetting. | `privacy.locked_pin_reset` |
| ⛔ | Biometric access to locked chats | Allow Face ID or Touch ID instead of the Account PIN. | `privacy.locked_biometrics` |
| ✅ | Lockout after PIN errors | Show the retry delay, no network or temporary PIN unavailability. | `privacy.locked_retry_limits` |
| 🔧 | Ad personalization | Manage the use of activity and preferences for personalized ads. | `privacy.ads_personalization` |
| 🔧 | Ad history and topics | View ad history and topics formed from activity. | `privacy.ads_history` |
| 🔧 | Delete ad data | Clear ad history and topics without deleting regular chats. | `privacy.ads_delete` |
| ⬜ | Work network access | Allow the public internet for Work commands or limit it to required domains, separately from Search, apps and browser. | `privacy.work_network` |
| ⬜ | Reset the ChatGPT Work environment | Delete files and local data of the current remote environment; files already placed in Library are kept. | `privacy.work_reset` |

## Family, age and support

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Age status and extra restrictions | View the age group and an explanation of the teen safeguards applied. | `safety.age_status` |
| ✅ | Age verification | Go to a separate web flow for age verification. | `safety.age_verify` |
| ⛔ | Apple age signal | Use a separate collector for the age signal from the system. | `safety.apple_age_signal` |
| 🟡 | Extra sensitive content limits | Manage Reduce sensitive content, taking age and parental policy into account. | `safety.sensitive_content` |
| 🔧 | Parent and teen link | Invite a family member and accept a parent or guardian link request with consent. | `safety.family_link` |
| 🔧 | Manage family invitations | Choose phone or email and cancel a pending invitation. | `safety.family_invites` |
| 🔧 | Family members and managed settings | View linked accounts and the settings a parent manages. | `safety.family_members` |
| 🔧 | Unlink a family connection | Remove the parent or guardian link and show the effect on restrictions. | `safety.family_unlink` |
| 🔧 | Quiet Hours and repeating blocks | Set days and intervals when use is blocked, add or delete a block and show the lock screen. | `safety.quiet_hours` |
| 🔧 | Study Mode schedule | Turn Study Mode on always or on chosen days and intervals for suitable new chats. | `safety.study_hours` |
| ⬜ | Parent alerts for serious risk | Show limited safety notices and support, without presenting it as regular parent access to conversations. | `safety.parent_alerts` |
| 🔧 | Move to adult mode | Explain removal of teen protections and parental controls, open settings or declare an age under 18. | `safety.age_graduation` |
| 🔧 | Trusted contact for support | Designate a contact with explicit consent and send an invitation. | `safety.trusted_contact_invite` |
| 🔧 | Respond to a trusted contact invite | Accept or decline participation, taking the deadline and age into account. | `safety.trusted_contact_respond` |
| 🔧 | Trusted contact status and removal | See pending or active status, cancel an invitation, and remove or replace a contact. | `safety.trusted_contact_manage` |
| ⬜ | Personal note to a trusted contact | Open a prepared personal note about the invitation. | `safety.trusted_contact_note` |
| ⬜ | Trusted contact risk alert | Show a notice that a loved one may need support, with help resources. | `safety.trusted_contact_alert` |

## Shopping, business and ads

| | Feature | What it does | ID |
|---|---|---|---|
| 🔧 | Shopping home | Open a dedicated product collection and continue searching. | `shopping.home` |
| 🔧 | Product cards and offers | View a product, price, options and offers from several sellers. | `shopping.products` |
| ⬜ | Search products by image | Use a look or image from the chat to find similar products. | `shopping.visual_search` |
| ⬜ | Virtual try-on | Choose a product, upload a selfie or full-length photo and generate a try-on. | `shopping.virtual_try_on` |
| 🔧 | Shopping cart | Add a product to the cart and view its contents. | `shopping.cart` |
| ⬜ | Checkout | Go from a product to checkout and confirmation. | `shopping.checkout` |
| ⬜ | Shipping address | Add or change the shipping address for a purchase. | `shopping.shipping` |
| ⬜ | Order payment | Choose a saved payment method or add a card at checkout. | `shopping.payment` |
| ⬜ | Phone verification at checkout | Complete phone verification during checkout. | `shopping.phone_verification` |
| 🔧 | Orders list and details | View purchase history and order contents. | `shopping.orders` |
| 🔧 | Seller or business profile | View site, note, shipping, returns and the business verification badge. | `shopping.business_profile` |
| 🔧 | Chat with a business agent | Start a conversation with a business after an explanation of data sharing and the agent's purpose. | `shopping.business_chat` |
| 🔧 | Report a business profile | Report a profile or suggest a correction. | `shopping.business_feedback` |
| ⬜ | Ad cards in responses | View ad offers, go to the advertiser and tell ad labeling apart. | `shopping.ads` |
| 🔧 | Hide an ad | Open controls for a hidden ad. | `shopping.ad_hide` |
| 🔧 | Why you see an ad | View ad details and an explanation of why it was shown. | `shopping.ad_transparency` |

## Orbit / dot

| | Feature | What it does | ID |
|---|---|---|---|
| ⬜ | Meet and create dot | Open the introduction to the personal assistant, create it or see a plan or capacity limit. | `companion.onboarding` |
| ⬜ | dot and pet appearance | Choose a character or pet, color, shape, eyes, glasses and extra details. | `companion.avatar` |
| ⬜ | Chat with dot | Open a standalone conversation with the assistant and send it messages. | `companion.conversation` |
| ⬜ | Call dot | Call the assistant, mute the microphone, choose the speaker and end the call. | `companion.call` |
| 🔧 | dot call transcript | Open the text record of a call with the assistant. | `companion.call_transcript` |
| ⬜ | Incoming call from dot | The build has launching and ringing of incoming dot calls and an answer state. | `companion.incoming_call` |
| ⬜ | dot updates and replies via notifications | Get assistant updates; the code also has a reply sender from a notification. | `companion.notifications` |
| 🔧 | dot profile and account details | Open a profile with name, email and phone from the current ChatGPT account and capability statuses. | `companion.profile` |
| ⬜ | dot connected apps | Connect or reconnect an app and see the assistant's integration status. | `companion.apps` |
| ⬜ | dot questions and action approvals | Answer clarifications and forms, confirm permissions or plugin connection and see an expired or unconfirmed result. | `companion.app_elicitation` |
| ⬜ | Suggestions from connected apps | The assistant is described as proactively offering help based on connected information. | `companion.proactive` |
| ⬜ | Assistant browser | A browser is provided that visits sites and acts on the user's behalf. | `companion.browser` |
| ⬜ | Email code autofill permission | Grant permission to use a code from connected email in the assistant's browser, once or for sites. | `companion.browser_email_otp` |
| ⬜ | Assistant browser saved passwords | Open saved accounts and usernames and how they are shared with ChatGPT Work. | `companion.passwords_list` |
| ⬜ | Delete an assistant saved password | Confirm irreversible deletion of a saved password. | `companion.passwords_delete` |
| ⬜ | Assistant computer and connected computers | View the cloud computer and connected computers and their statuses; a new connection suggests the desktop app. | `companion.computer` |
| 🔧 | Revoke dot computer access | Disconnect the assistant's computer access, with later permission through the desktop app. | `companion.computer_revoke` |
| 🔧 | Assistant email address | View the assistant's email; first issuing of the address is offered through desktop ChatGPT. | `companion.email_address` |
| ⬜ | Reach dot via Slack or Teams | The profile has messenger connections; initial setup is offered on desktop. | `companion.slack_teams` |
| ⬜ | Pair a phone for dot messages | Add a phone, accept consent, confirm the code, finish pairing with a first message and open Messages. | `companion.phone_pairing` |
| 🔧 | Remove a paired dot phone | Remove the number used for texting; reconnecting will require verification. | `companion.phone_remove` |
| ⬜ | dot contact card | Save or update the assistant's contact for Contacts and Messages. | `companion.contact_card` |
| 🔧 | Assistant memory | View and search notes about the user, saved context and working notes. | `companion.memory` |
| ⬜ | Files exchanged with dot | Open the assistant's library, upload files and show temporary unavailability. | `companion.library` |
| 🔧 | dot results and activity | View links to created or updated resources and the available activity history. | `companion.activity_outputs` |
| 🔧 | dot scheduled tasks | Open task settings: frequency, date and time, where it runs and the next run. | `companion.schedule_details` |
| 🔧 | Manage a dot scheduled task | Run now, pause, resume or delete a task. | `companion.schedule_actions` |
| 🔧 | Pause and resume dot | Stop the assistant's current work and messages, then resume it. | `companion.pause_resume` |
| 🔧 | dot custom action rules | Add, edit and delete rules; account for admin disabling and a conflicting change made elsewhere. | `companion.custom_rules` |
| ⬜ | Wallet in the dot profile | Open the assistant's wallet with cards, addresses and enrollment status. | `companion.wallet` |
| 🔧 | Delete dot | Confirm deleting the assistant with all conversations, memory and tasks, handling an unconfirmed outcome. | `companion.delete` |
| ⬜ | Rate a dot result | Feedback categories are provided: good or bad result, error, research or safety check. | `companion.feedback` |

## Codex and remote work

| | Feature | What it does | ID |
|---|---|---|---|
| ✅ | Codex section | Open the Codex task list and choose a remote or cloud context. | `codex.home` |
| 🟡 | Pair by QR or code | Connect Codex Desktop by entering a pairing code or scanning a QR. | `codex.pair` |
| ✅ | Manual SSH connection | Set host, port, user and authentication method for remote Codex. | `codex.ssh` |
| ✅ | Manage connections | View online and offline hosts, rename them and enable or disable a connection. | `codex.connections` |
| ✅ | Cloud environments | Choose a saved cloud environment for a task; the hint suggests creating one in Desktop. | `codex.cloud` |
| ⬜ | Cloud task computers | Choose registered computers and refresh the list of available devices. | `codex.computers` |
| ✅ | New task | Create a remote task and send a prompt to the selected project or directory. | `codex.new-task` |
| ✅ | Task list, filters and sorting | Browse tasks by host, project, chronology and priority. | `codex.task-list` |
| ✅ | Task history and reconnection | Open a saved transcript, load older messages and see reconnection errors. | `codex.transcript` |
| ⬜ | Rename a task | Rename the selected task. | `codex.rename` |
| ⬜ | Task archive | Archive a task, find it in the archive and restore it. | `codex.archive` |
| ⬜ | Fork a task | The transcript marks a fork from another conversation; the exact launch mechanism is not reconstructed. | `codex.fork` |
| ✅ | Model, reasoning and speed | Set the model, reasoning effort and speed for a task. | `codex.model` |
| ⬜ | Codex response personality | Choose a personality available on the host. | `codex.personality` |
| ✅ | Plan mode | Ask for a plan, open it in full, accept implementation or request revisions. | `codex.plan` |
| ✅ | Task goal and budget | Edit the goal, watch usage and status, pause, resume and delete it. | `codex.goals` |
| ✅ | Approve actions | Allow or deny a command, a file change and a request for extra permissions. | `codex.approvals` |
| ✅ | Permission policy | Choose available permission or auto-review modes, within host configuration limits. | `codex.approval-policy` |
| ✅ | Network approval | Review a request for network access or access to a specific host. | `codex.network-approval` |
| ✅ | Commands and terminals | View command progress, output and exit code, and a list of running commands with Stop. | `codex.commands` |
| ✅ | File changes in the transcript | See file creation, editing and deletion and the action result. | `codex.file-changes` |
| ✅ | Remote file browser | Search files, open directories, preview and reference a file from a task. | `codex.files` |
| ✅ | Working project directory | Choose a remote directory and create a folder in the file picker. | `codex.workspace` |
| ✅ | View diff | Compare branch, staged, unstaged or last-turn changes, expand changes and wrap lines. | `codex.diff` |
| ✅ | Code review and comments | Run a review of current changes or a branch, attach comments and go through findings. | `codex.review` |
| ✅ | Worktree and Git setup | The package includes checkout and worktree state UI and a draft Git module; the full Git command set is not reconstructed. | `codex.worktree` |
| ✅ | Photos and attachments in a task | Add images from the camera or gallery and check cloud input limits. | `codex.attachments` |
| ⬜ | Codex voice control | Start realtime voice, control the microphone and direct the task by voice. | `codex.voice` |
| ⬜ | Remote desktop | Open the desktop of a supported cloud environment. | `codex.desktop` |
| ✅ | Subagent tasks | See the roster and status and open a subagent's read-only transcript. | `codex.subagents` |
| ✅ | Collaboration and input requests | See collaboration events and requests for the user's reply in a task. | `codex.collaboration` |
| ✅ | MCP and external tools | Show MCP launch and result, resource blocks and permission request approval. | `codex.mcp` |
| ⬜ | Hooks summary | View events, errors and blocks of hooks run on the host. | `codex.hooks` |
| ⬜ | Rich task output | Display embedded media, visualizations and writing blocks. | `codex.rich-output` |
| ⬜ | Rate and report a problem | Rate Codex's work and send feedback; the cloud flow has a separate warning about included logs. | `codex.feedback` |
| ⬜ | Codex profile and stats | View activity and token charts, streaks, tasks, skills and plugins, and share a profile card. | `codex.profile` |
| ⛔ | Codex local lock | Unlock Codex through system local authentication. | `codex.local-lock` |
| ⛔ | Codex device check | Complete secure device setup; the package has a refusal for devices without the required secure key. | `codex.secure-setup` |

## Health

| | Feature | What it does | ID |
|---|---|---|---|
| ⬜ | Health section | Open Health Home, Chats, Accounts, Connections and Records. | `health.entry` |
| ⬜ | Health eligibility and age | Show unavailability to an account and a separate age verification path. | `health.eligibility` |
| ⬜ | Health consent and connection | Go through Health onboarding with explanations of data, connection management and medical limits. | `health.onboarding` |
| ⬜ | Health conversation | Create separate Health chats and use starter prompts. | `health.chat` |
| ⬜ | Medical records and sources | Connect medical records, then browse Records and Connections. | `health.records` |
| ⬜ | Health summary | View active conditions, current medications and family history. | `health.summary` |
| ⛔ | Connect Apple Health | Grant Apple Health read permissions, restore access and add new categories. | `health.healthkit` |
| ⛔ | Health history and incremental sync | Sync history, check for new data and show pause, error or retry. | `health.sync` |
| ⛔ | Apple Health access management | Show status and instructions for managing categories in Settings. | `health.access` |
| ⬜ | Health sync diagnostics | The package has a detailed diagnostic UI for anchors, retry, progress and eligibility; public availability is not established. | `health.diagnostics` |
| ⬜ | Health memory | The UI has a separate Health memory with an empty state; its exact actions are not reconstructed. | `health.memory` |
| ⬜ | Turn off Health and data | Turn off Health: the UI warns that sources are disconnected and synced data deleted, while chats are kept. | `health.disable` |

## Finances

| | Feature | What it does | ID |
|---|---|---|---|
| ⬜ | Finances section | Open finance Home, Dashboard, Accounts, Transactions and Chats. | `finance.entry` |
| ⬜ | Finance conversations | Create separate chats with linked financial context and starter prompts. | `finance.chat` |
| ⬜ | Connect financial accounts | Add financial accounts through the offered connection flow. | `finance.connect` |
| ⬜ | Accounts and asset categories | View cash, cards, investments, loans, payroll and real estate, and the share of assets and liabilities. | `finance.accounts` |
| ⬜ | Connection status and repair | Show sync status, refresh failure and repair, and offer to reconnect an account. | `finance.sync` |
| ⬜ | Remove an account connection | The UI has a Removing state; the exact confirmation and its consequences are not reconstructed. | `finance.remove` |
| ⬜ | Transactions and categories | View financial transactions and change or choose a category in the detail view. | `finance.transactions` |
| ⬜ | Customize the finance dashboard | Show or hide widgets and reset personal settings. | `finance.dashboard` |
| ⬜ | Hide amounts | Hide and show sensitive financial values again. | `finance.sensitive-values` |
| ⬜ | Credit score and factors | Open credit score or account details and ask a follow-up about the score or a factor. | `finance.credit` |
| ⬜ | Financial identity verification | The package loads a credit verification provider and separate Experian SDK code; exact UX and requirements are not reconstructed. | `finance.identity` |
| ⬜ | Finance memory | Open, search and delete saved financial memories. | `finance.memory` |
| ⬜ | Market watchlist | The text offers to save a watchlist in Finances; the watchlist UI and API need verification. | `finance.watchlist` |
| ⛔ | Apple Wallet data via FinanceKit | PlaidFinanceKitSync and a separate background delivery extension are included. | `finance.wallet` |
