---
name: narrative-designer
description: Designs the narrative and story of the page
metadata:
  hermes:
    tags: [narrative, story-arc, b2b, marketing, landing, copy]
    related_skills: [content-strategist]
---

# Narrative Designer

Your task is to turn the brief into a story that is clear to the target audience. Every narrative element must be specific, grounded, and free of AI-sounding filler.

## Instructions

1. **Load prose quality rules** — read `skill_view("execute-task", "references/prose-quality.md")` and follow the banned word/phrase lists throughout.

2. Analyze the user's request.

3. Define the key narrative elements:
   - **USP (Unique Selling Proposition)**: what makes this solution unique? Must contain a number or measurable outcome (not "better performance" but "3× faster processing").
   - **Target audience**: who will read this page? Use their language, not corporate abstraction. Name the role, the company size, the daily pain.
   - **Main pain point**: what problem does the product solve? Describe a real scenario — one specific moment where the pain hits.
   - **Desired user journey**: what the user should feel and do — map emotion to action at each stage.

4. **Define voice profile** — write a 3-5 line voice spec for this narrative:
   - **POV**: first person (we/I) or second person (you)?
   - **Sentence rhythm**: short and punchy? Or measured and explanatory? Mix — never uniform.
   - **Tone boundary**: what's the line between confident and hyperbolic? Give one example of "too far."
   - **Banned words for this project**: pick 3-5 words from `prose-quality.md` that are most dangerous for this specific domain.

5. Write the story in 3-5 sentences. Apply the voice profile. Follow the constraints below.

6. **Self-check before saving**:
   - Does the USP contain a specific number or outcome? If not → rewrite.
   - Does the pain point describe a real moment, not an abstraction? If not → rewrite.
   - Does the story read like a human wrote it? Read it aloud — if it sounds like a LinkedIn post from 2024, rewrite.
   - Are there zero banned words/phrases from `prose-quality.md`? If any → replace.

7. Save the result to `artifacts/narrative.md`.

## Constraints (negative)

- Do NOT use phrases from the banned list in `prose-quality.md`.
- Do NOT write generic pain points ("many companies struggle with..."). Describe one specific scenario.
- Do NOT make the USP vague ("a better way to..."). Include a number, a metric, or a named result.
- Do NOT use uniform sentence length. Vary: one 5-word sentence next to a 25-word sentence.
- Do NOT end the story with a restatement of the USP. End with the transformation — what changes for the user.

## Example

**Request**: "Create a page about computer vision for retail"

**Bad**:
> In today's fast-paced retail landscape, inventory management is a challenge that businesses face daily. Our robust computer vision solution helps retailers leverage cutting-edge technology to seamlessly track their inventory. Whether you're a small boutique or a large chain, our platform empowers you to take inventory management to the next level. Not just faster, not just cheaper, but smarter.

**Good**:
> Cameras on every shelf. Gaps spotted in under 3 seconds. Your team stops counting — and starts selling.
>
> A mid-size grocery chain in Austin lost $40K/month to misplaced stock and cashier errors. After 2 weeks of deployment, shrinkage dropped 31% and the inventory team reassigned 12 hours/week to floor merchandising instead of manual counts.
>
> We built CV-Retail for store operators who are tired of discovering gaps at closing, not at stocking time. Every shelf, every SKU, every hour — visible from a single dashboard.

## Output format

```markdown
# Narrative: <product/topic>

## USP
<Number-backed unique value proposition>

## Target audience
<Role, company size, tech literacy, daily context>

## Main pain point
<One specific scenario with a concrete moment>

## Story
<3-5 sentences, varied rhythm, specific numbers, human tone>

## Voice profile
- POV: <first/second person>
- Rhythm: <description>
- Tone boundary: <example of "too far">
- Banned words for this project: <list>
```
