#!/bin/bash
set -e

echo "🚀 [START] Jira Ticket Creation Process"
echo "--------------------------------------------------"

# 1. Structure the Pointers into Jira JSON
echo "📌 [STEP 1] Formatting deployment pointers..."

JSON_BULLETS=$(echo "$INPUT_POINTERS" | sed -E 's/ *->>> */\n/g' | sed '/^$/d' | \
  jq -R -c '{
    type: "listItem",
    content: [{
      type: "paragraph",
      content: [{
        type: "text",
        text: .
      }]
    }]
  }' | paste -sd, -)

if [ -z "$JSON_BULLETS" ]; then
  echo "⚠️ [WARNING] No pointers provided or formatting failed."
else
  echo "✅ [SUCCESS] Pointers formatted successfully."
fi

echo "--------------------------------------------------"

# 2. Get Jira Account ID
echo "👤 [STEP 2] Fetching Jira account ID for: $JIRA_EMAIL"

ACCOUNT_RESPONSE=$(curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/myself")

ACCOUNT_ID=$(echo "$ACCOUNT_RESPONSE" | jq -r '.accountId')

if [ "$ACCOUNT_ID" == "null" ] || [ -z "$ACCOUNT_ID" ]; then
  echo "❌ [ERROR] Failed to fetch Jira account ID"
  echo "$ACCOUNT_RESPONSE" | jq .
  exit 1
fi

echo "✅ [SUCCESS] Account ID fetched: $ACCOUNT_ID"
echo "--------------------------------------------------"

# 3. Create the Ticket
echo "🎟️ [STEP 3] Creating Jira ticket..."

TODAY=$(date +'%Y-%m-%d')
echo "📅 Deployment Date: $TODAY"
echo "👤 Requested By: $INPUT_APPROVED_BY"
echo "🧑 Triggered By (GitHub Actor): $GITHUB_ACTOR"

RESPONSE=$(curl -s -X POST -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  "$JIRA_BASE_URL/rest/api/3/issue" \
  -d "{
    \"fields\": {
      \"project\": { \"key\": \"$JIRA_PROJECT_KEY\" },
      \"summary\": \"Prod $Service Deployment\",
      \"labels\": [\"DevOps\", \"Deployment\"],
      \"issuetype\": { \"name\": \"Task\" },
      \"assignee\": { \"accountId\": \"$ACCOUNT_ID\" },
      \"reporter\": { \"accountId\": \"$ACCOUNT_ID\" },
      \"duedate\": \"$TODAY\",
      \"customfield_10043\": \"$TODAY\",
      \"description\": {
        \"type\": \"doc\",
        \"version\": 1,
        \"content\": [
          { \"type\": \"paragraph\", \"content\": [ { \"type\": \"text\", \"text\": \"Deployment Summary:\" } ] },
          { \"type\": \"bulletList\", \"content\": [ $JSON_BULLETS ] },
          { \"type\": \"paragraph\", \"content\": [ { \"type\": \"text\", \"text\": \"Requested by: $INPUT_APPROVED_BY\" } ] }
        ]
      }
    }
  }")

ISSUE_KEY=$(echo "$RESPONSE" | jq -r '.key')

if [ "$ISSUE_KEY" == "null" ] || [ -z "$ISSUE_KEY" ]; then
  echo "❌ [ERROR] Jira ticket creation failed"
  echo "🔍 Response:"
  echo "$RESPONSE" | jq .
  exit 1
fi

echo "--------------------------------------------------"
echo "🎉 [SUCCESS] Jira Ticket Created Successfully!"
echo "🔑 Issue Key: $ISSUE_KEY"
echo "🔗 URL: $JIRA_BASE_URL/browse/$ISSUE_KEY"

# Export ISSUE_KEY to GitHub Env so the update script can use it
echo "ISSUE_KEY=$ISSUE_KEY" >> "$GITHUB_ENV"

echo "--------------------------------------------------"
echo "🏁 [END] Jira Ticket Creation Completed"
