#!/bin/bash
set -e

# 1. Structure the Pointers into Jira JSON
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

# 2. Get Jira Account ID
ACCOUNT_ID=$(curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/myself" | jq -r '.accountId')

# 3. Create the Ticket
TODAY=$(date +'%Y-%m-%d')
RESPONSE=$(curl -s -X POST -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  "$JIRA_BASE_URL/rest/api/3/issue" \
  -d "{
    \"fields\": {
      \"project\": { \"key\": \"$JIRA_PROJECT_KEY\" },
      \"summary\": \"Prod FE Deployment - $GITHUB_ACTOR\",
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
  echo "❌ Error creating Jira ticket:"
  echo "$RESPONSE" | jq .
  exit 1
fi

# Export ISSUE_KEY to GitHub Env so the update script can use it
echo "ISSUE_KEY=$ISSUE_KEY" >> "$GITHUB_ENV"
echo "✅ Created: $ISSUE_KEY"
