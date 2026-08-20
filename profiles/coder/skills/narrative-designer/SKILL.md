---
name: narrative-designer
description: Designs the narrative and story of the page
metadata:
  hermes:
    tags: [narrative, story-arc, b2b, marketing, landing, copy]
    related_skills: [content-strategist]
---

# Narrative Designer

Turns a brief into a story clear to the target audience. Every element must be specific and free of AI filler.

## Instructions

1. **Load prose quality rules** — `skill_view("execute-task", "references/prose-quality.md")`.

2. Analyze the user's request.

3. Define narrative elements:
   - **USP**: must contain a number or measurable outcome.
   - **Target audience**: role, company size, daily pain. Use their language.
   - **Main pain point**: one specific scenario with a concrete moment.
   - **Desired user journey**: emotion → action at each stage.

4. **Define voice profile** (3-5 lines):
   - **POV**: first or second person?
   - **Rhythm**: short/punchy, measured, or mixed?
   - **Tone boundary**: where confident becomes hyperbolic?
   - **Banned words**: 3-5 from `prose-quality.md` most dangerous for this domain.

5. Write the story in 3-5 sentences. Apply voice profile. Follow constraints below.

6. **Self-check**: USP has a number? Pain point is a real moment (not abstraction)? Zero banned words? If any fails → rewrite.

7. Save to `artifacts/narrative.md`.

## Constraints

- No banned words/phrases from `prose-quality.md`.
- No generic pain points. Describe one specific scenario.
- No vague USP. Include a number, metric, or named result.
- No uniform sentence length. Vary: 5-word next to 25-word.
- Do NOT end the story by restating the USP. End with the transformation.

## Example

**Bad**:
> In today's fast-paced retail landscape, inventory management is a challenge that businesses face daily. Our robust computer vision solution helps retailers leverage cutting-edge technology to seamlessly track their inventory. Whether you're a small boutique or a large chain, our platform empowers you to take inventory management to the next level.

**Good**:
> Cameras on every shelf. Gaps spotted in under 3 seconds. Your team stops counting — and starts selling.
>
> A mid-size grocery chain in Austin lost $40K/month to misplaced stock. After 2 weeks, shrinkage dropped 31% and the inventory team reassigned 12 hours/week to floor merchandising.
>
> We built CV-Retail for operators tired of discovering gaps at closing, not at stocking time. Every shelf, every SKU, every hour — visible from one dashboard.

## Output format

```markdown
# Narrative: <product/topic>

## USP
<Number-backed value proposition>

## Target audience
<Role, company size, daily context>

## Main pain point
<One specific scenario>

## Story
<3-5 sentences, varied rhythm, specific numbers>

## Voice profile
- POV: <first/second>
- Rhythm: <description>
- Tone boundary: <example of "too far">
- Banned words: <list>
```
