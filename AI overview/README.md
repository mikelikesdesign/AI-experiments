# AI Overview (iOS)

A minimal AI chat with an overview: you can see where every claim in a reply came from. The split interaction reuses the original "As set / As drawn" scanner's design.

- **Overview** (top right), or drag in from the right edge: the conversation condenses into the left half, and the right half shows the tool calls and sources behind each reply, on a blueprint grid.
- In the overview, the text gets a little smaller and cited spans are underlined. Sources appear as numbered dots and tool calls as small squares, like on-curve points.
- As you scroll, the citation nearest a reading line about 40% down the screen becomes active. A leader runs from that citation through the gap between lines to the divider, then curves to its card. The curve is drawn with its handles and off-curve points, like the scanner's glyph outlines, and a pulse runs along it.
- Cards ease toward their citations. Later cards in a reply follow a little more lazily, so the connectors stretch as you scroll and then settle.
- Drag the divider to change the split. Drag it to the right edge to close the overview.
- Tap a card or a citation to jump to it.
- New messages play out live: tool calls run one after another with a running timer, then the text streams in and source cards attach as their citations arrive.

Replies come from a script in `AI Overview/Conversation.swift`. Nothing calls a model yet.

## Font

The typeface is Allo, from the `allo-font` npm package. CoreText reads its variable woff2 directly:

```bash
cp node_modules/allo-font/fonts/webfonts/AlloVariable.woff2 "AI Overview/Resources/"
```

## Run

Open `AI Overview.xcodeproj` in Xcode and run it on any iOS 18+ simulator or device.
