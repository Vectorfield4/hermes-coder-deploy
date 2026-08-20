---
name: content-strategist
description: Creates a content plan based on the narrative
metadata:
  hermes:
    tags: [copy, headline, cta, microcopy, marketing, seo]
    related_skills: [narrative-designer]
---

# Content Strategist

Writes a structured content plan based on the narrative. Every block must pass anti-AI-pattern checks.

## Instructions

0. **Load prose quality rules** — `skill_view("execute-task", "references/prose-quality.md")`. Every sentence is checked against it.

1. Read `artifacts/narrative.md`. Extract the voice profile and apply it to every block.

2. Create a content plan with these blocks:
   - **H1**: Specific outcome + clear audience (not generic).
   - **Subheadline**: What the product does — one sentence, no fluff.
   - **Block 1 (Hero)**: USP + CTA. CTA = actual next step ("See a 2-min demo").
   - **Block 2 (Problem)**: One specific pain scenario with a number.
   - **Block 3 (Solution)**: The mechanism — what does it actually do?
   - **Block 4 (Benefits)**: 3-5 benefits, each with a number/constraint. No repetition. Order by importance.
   - **Block 5 (Cases/Proof)**: Named example or real number. If none → concrete scenario.
   - **Block 6 (CTA)**: Explicit about what happens next.

3. Each block: heading, text (2-3 sentences, varied length), recommended visual.

4. **Self-check** (before saving):
   - Zero banned words/phrases from `prose-quality.md`.
   - Every paragraph adds NEW information.
   - Read aloud — if it sounds like LinkedIn → rewrite.

5. Save to `artifacts/content-plan.md`.

## Example

**Bad**:
> **Headline**: Empower Your Team with Smarter Inventory
> **Text**: In today's fast-paced retail environment, managing inventory efficiently is crucial for success. Our robust platform leverages cutting-edge computer vision to seamlessly track your inventory in real-time. Whether you're a small shop or a large chain, we help you take control.
> **CTA**: Get Started

**Good**:
> **Headline**: Stop Counting Shelves. Start Selling Products.
> **Text**: Cameras watch every shelf. Gaps appear on your dashboard in under 3 seconds. Your inventory team gets 12 hours back every week — time they used to spend walking aisles with clipboards.
> **CTA**: See a 2-minute demo
