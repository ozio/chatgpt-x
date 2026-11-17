# App icon and brand marks

The Home Screen icon is an emerald glass tile in the iOS 6 style, with the white
six-loop mark and a strong cast shadow. It is a new drawing in the iOS 6 style of
the OpenAI logo. OpenAI's name and mark remain OpenAI's property, and this
unofficial project is not affiliated with OpenAI.

| File | Purpose |
|---|---|
| `ChatGPT-iOS6.vectorcraft`, `ChatGPT-iOS6.svg` | Editable master and its portable SVG |
| `icon-{29,57,58,114,144,192,512,1024}.png` | Opaque square raster exports |
| `manifest.json` | Export sizes and hashes |
| `marks/` | Containerless marks used inside the app (see its README) |

The app's resource folder `ios/standalone/chat-app/Resources` contains the
selected icon as `Icon-Tumblr*.png`. `UIPrerenderedIcon=true` stops iOS from
adding a second gloss. The plain `Icon*.png` files are compatibility copies of
the same icon.
