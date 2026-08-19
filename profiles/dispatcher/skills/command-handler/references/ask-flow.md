# Ask Flow

Handles `/ask <question>` — answers a question using RAG recall. No task is created.

## Input
- `question` — text after `/ask`
- `chat_id` — from `{{ env.TELEGRAM_CHAT_ID }}`

## Steps

1. **Validate question**
   - If empty → reply: "Please ask a question after /ask."

2. **Recall context (RAG E-pool)**
   - Call `mcp_dense_mem_recall_memory(query="<question>")`.
   - If a project name is mentioned in the question, also recall project-specific context:
     `mcp_dense_mem_recall_memory(query="<question>", filter={tags: ["project:<project>"]})`.
   - Graceful degradation: if MCP call fails, proceed with LLM's built-in knowledge.

3. **Generate answer**
   - Use the recalled context (if any) + the original question to generate a concise answer.
   - If the recall returned relevant project rules or past experience — reference them.
   - If no relevant context found — answer from general knowledge, note that no project-specific context was found.

4. **Reply**
   - Send the answer as a Telegram message.
   - Keep it concise (under 2000 characters for Telegram). If longer, summarize and offer to create a task for deeper investigation.
