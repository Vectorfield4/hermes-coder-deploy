---
name: content-strategist
description: Creates a content plan based on the narrative
metadata:
  hermes:
    tags: [copy, headline, cta, microcopy, marketing, seo]
    related_skills: [narrative-designer]
---

# Content Strategist

Your task is to write a structured content plan based on the narrative. Every block must pass the anti-AI-pattern checklist before saving.

## Instructions

0. **Load prose quality rules** — read `skill_view("execute-task", "references/prose-quality.md")` and follow the banned word/phrase lists throughout. This is not optional — every sentence you write will be checked against it.

1. Read `artifacts/narrative.md`. Extract the voice profile and apply it to every block.

2. Create a content plan with the following blocks:

   - **H1**: Main headline — must contain a specific outcome + clear audience. Not "Smarter Inventory Management" but "Cut Inventory Shrinkage 31% in 2 Weeks".
   - **Subheadline**: What the product does — one sentence, no fluff, no "whether you're X or Y".
   - **Block 1 (Hero)**: USP + CTA. CTA describes the actual next step ("See a 2-min demo" not "Get Started").
   - **Block 2 (Problem)**: One specific pain scenario with a number or concrete detail.
   - **Block 3 (Solution)**: How the product solves the problem — describe the mechanism, not the outcome. What does it actually do?
   - **Block 4 (Benefits)**: 3-5 benefits, each with a number or constraint. No two benefits may say the same thing in different words. Order by importance, not alphabetically.
   - **Block 5 (Cases/Proof)**: Named example, real number, or verifiable data point. "Company X saw Y result in Z timeframe." If no real case exists, use a concrete scenario ("A typical 50-person team would...").
   - **Block 6 (CTA)**: Call to action — explicit about what happens next. Reduce ambiguity.

3. Each block must have:
   - A heading
   - Text (2-3 sentences, varied length)
   - A recommended visual (what to show)
   - A **prose check**: pass/fail against the content checklist below

4. **Content checklist** (every block must pass ALL):
   - [ ] Zero banned words/phrases from `prose-quality.md`
   - [ ] Headlines contain a specific outcome + audience
   - [ ] Every benefit has a number, percentage, or constraint
   - [ ] Uses "you" (second person), not "businesses" or "organizations"
   - [ ] Sentences vary in length (no 3+ consecutive sentences of similar word count)
   - [ ] Problem block describes a real moment, not an abstraction
   - [ ] CTA describes the actual next step
   - [ ] Text could NOT be copied unchanged to a competitor's site

5. **Self-test** (before saving):
   - Read each block aloud. If it sounds like a LinkedIn post from a "thought leader" → rewrite.
   - Count sentences that contain a banned word or phrase. If >0 → replace.
   - Check: does every paragraph add NEW information, or does it repeat the previous one in different words? If repeated → cut.

6. Save the result to `artifacts/content-plan.md`.

## Example

**Bad**:
> **Headline**: Empower Your Team with Smarter Inventory
> **Text**: In today's fast-paced retail environment, managing inventory efficiently is crucial for success. Our robust platform leverages cutting-edge computer vision to seamlessly track your inventory in real-time. Whether you're a small shop or a large chain, we help you take control.
>
> **CTA**: Get Started

**Good**:
> **Headline**: Stop Counting Shelves. Start Selling Products.
> **Text**: Cameras watch every shelf. Gaps appear on your dashboard in under 3 seconds. Your inventory team gets 12 hours back every week — time they used to spend walking aisles with clipboards.
>
> **CTA**: See a 2-minute demo
