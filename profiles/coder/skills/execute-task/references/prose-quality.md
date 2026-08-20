# Prose Quality Reference (Anti-AI-Patterns for Marketing Text)

Loaded by `content-strategist` and `narrative-designer` before generating marketing copy. Also used by `execute-task` and `pr-judge` as a content quality overlay.

## Banned Lexical Tells

These words are the strongest AI signals. Replace with plain equivalents before committing.

| Banned | Replace with |
|--------|-------------|
| leverage (verb) | use |
| robust | solid, reliable |
| seamless | smooth (or remove) |
| navigate (metaphorical) | handle, deal with |
| delve | dig into, explore |
| embark | start, begin |
| unveil | show, reveal |
| truly | (delete) |
| deeply | (delete) |
| fundamentally | (delete) |
| utilize | use |
| facilitate | help, enable |
| enumerate | list, count |
| ascertain | find out, determine |
| subsequently | then, later |
| commence | start |
| terminate | end, stop |
| regarding | about, on |
| furthermore | (delete or use "and") |
| moreover | (delete or use "and") |
| consequently | so, therefore |

## Banned Phrases

Delete entirely or rewrite from scratch.

| Banned phrase | Replacement |
|--------------|-------------|
| "in today's fast-paced landscape/world" | State the actual context or delete |
| "whether you're X or Y" | Address one audience directly |
| "not just X, but Y" | State Y directly |
| "in a world where X" | Start with the problem |
| "X is more than just Y" | Describe what X actually does |
| "unlock the potential" | Name the specific outcome |
| "take it to the next level" | Describe the actual improvement |
| "game-changer" | Show the result with a number |
| "at the end of the day" | Delete |
| "it goes without saying" | Delete |
| "revolutionize" | Describe the specific change |
| "empower" | help, enable, give |
| "synergy", "synergize" | describe the actual combination |
| "holistic approach" | describe what you actually do |
| "cutting-edge" | name the specific technology |
| "best-in-class" | show evidence or delete |

## Banned Structural Patterns

These are sentence-level rhythms that signal AI generation.

### 1. Uniform sentence rhythm
**AI**: "Our platform helps teams collaborate. It reduces meeting time. It improves productivity. It saves money."
**Fix**: Vary length dramatically. Short punch after long explanation. Let emphasis drive structure.

### 2. Tri-colon overuse ("not A, not B, but C")
**AI**: "Not just faster, not just cheaper, but smarter."
**Fix**: State the point directly. One clear claim beats three decorative ones.

### 3. Paragraph-ending restatement
**AI**: Paragraph explains idea → last sentence restates the same idea in different words.
**Fix**: End paragraphs with a forward link, a specific detail, or just cut the last sentence.

### 4. Hedged superlatives
**AI**: "arguably one of the most innovative solutions on the market"
**Fix**: "used by 200+ teams" or delete the claim entirely.

### 5. False dichotomy intro
**AI**: "In a world where data is everywhere, companies face a choice: adapt or fall behind."
**Fix**: Start with the specific problem your reader has.

### 6. Lists that don't build
**AI**: Bullet items that repeat the same idea in slightly different words.
**Fix**: Order by importance or sequence. Each item must add new information.

## Content Quality Checklist

Every 500-word content block must pass ALL of these. If ≥3 fail → revise.

### Specificity
- [ ] Every benefit claim has a number, percentage, or named example
- [ ] Every "result" mentions a measurable outcome
- [ ] Abstract claims ("save time", "improve efficiency") are replaced with concrete ones ("cut invoice processing from 3 days to 2 hours")

### Voice & POV
- [ ] Uses "you" (second person) to address the reader directly, not "businesses" or "organizations"
- [ ] Has a clear point of view — takes a stance, doesn't present "both sides"
- [ ] Could NOT be copied unchanged to a competitor's website

### Tension & Honesty
- [ ] Acknowledges a tradeoff or limitation ("works best for teams under 20", "requires 2 weeks of setup")
- [ ] Doesn't overstate — no "will transform", "guarantees", "always works"
- [ ] Shows awareness of real-world constraints

### Structure
- [ ] Headlines contain a specific outcome + clear audience (not generic)
- [ ] Sentences vary in length (no 5 consecutive sentences of similar word count)
- [ ] No paragraph ends with a restatement of its opening claim

### CTA
- [ ] Describes the actual next step ("See a 2-minute demo" not "Get Started")
- [ ] Matches the destination (button text reflects what the user will actually find)

## Self-Test (for content-strategist output)

After writing a content block, run this diagnostic:
1. Give the text to someone unfamiliar with the product.
2. Ask: "Could this text appear unchanged on a competitor's site?"
3. If YES → rewrite with more specifics, tighter POV, real examples.
4. Count banned words/phrases from the lists above. If >0 → replace before saving.

## Scoring Guide (used by pr-judge for content overlay)

| Score | Criteria |
|-------|----------|
| 8-10 | Zero banned words, all claims have numbers/examples, clear POV, varied rhythm, honest tradeoffs |
| 6-7 | 1-2 banned words (auto-replaceable), most claims specific, POV present but could be sharper |
| 4-5 | Multiple banned words, several abstract claims, generic headlines, uniform rhythm |
| 1-3 | Reads as AI slop: no specifics, generic throughout, banned phrases in every paragraph |
