#!/bin/bash
set -e

echo "🚀 [START] Jira Ticket Update Process"
echo "--------------------------------------------------"

echo "📌 Issue Key: $ISSUE_KEY"
echo "📊 Job Status: $JOB_STATUS"

# Calculate Duration
echo "⏱️ [STEP 1] Calculating deployment duration..."

DURATION=$((END_TIME - START_TIME))
[ "$DURATION" -lt 60 ] && DURATION=60

echo "✅ Duration: $DURATION seconds"
echo "--------------------------------------------------"

# Helper function for transitions
echo "🔧 Preparing transition helper..."

get_transition_id() {
  curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
    "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions" \
    | jq -r ".transitions[] | select(.name==\"$1\") | .id"
}

echo "--------------------------------------------------"

if [ "$JOB_STATUS" == "success" ]; then

    echo "🎉 [SUCCESS FLOW] Deployment completed successfully"
    echo "--------------------------------------------------"

    # Log Work
    echo "⏳ [STEP 3] Logging work duration..."
    curl -s -X POST -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
      -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/worklog" \
      -d "{\"timeSpentSeconds\": $DURATION}"

    echo "✅ Worklog added"

    # Transition to Done
    echo "🔄 [STEP 4] Transitioning issue to DONE..."
    T_ID=$(get_transition_id "Done")

    if [ -z "$T_ID" ]; then
      echo "❌ [ERROR] Could not find 'Done' transition ID"
      exit 1
    fi

    echo "➡️ Transition ID: $T_ID"

    curl -s -X POST -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
      -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions" \
      -d "{\"transition\": {\"id\": \"$T_ID\"}}"

    echo "✅ Issue transitioned to DONE"

else

    echo "❌ [FAILURE FLOW] Deployment failed"
    echo "--------------------------------------------------"

    ERROR_MSG="Deployment failed. Logs: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"

    echo "📄 Error Message:"
    echo "$ERROR_MSG"

    # Update Estimate & Description
    echo "📝 [STEP 2] Updating Jira with failure details..."

    curl -s -X PUT -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
      -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY" \
      -d "{
        \"fields\": {
          \"timeoriginalestimate\": $DURATION,
          \"description\": {
            \"type\": \"doc\", \"version\": 1,
            \"content\": [
              {\"type\": \"paragraph\", \"content\": [
                {\"type\": \"text\", \"text\": \"$ERROR_MSG\"}
              ]}
            ]
          }
        }
      }"

    echo "✅ Jira updated with failure details"

    # Transition to Rejected
    echo "🔄 [STEP 3] Transitioning issue to REJECTED..."
    T_ID=$(get_transition_id "Rejected")

    if [ -z "$T_ID" ]; then
      echo "❌ [ERROR] Could not find 'Rejected' transition ID"
      exit 1
    fi

    echo "➡️ Transition ID: $T_ID"

    curl -s -X POST -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
      -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions" \
      -d "{\"transition\": {\"id\": \"$T_ID\"}}"

    echo "✅ Issue transitioned to REJECTED"
fi

echo "--------------------------------------------------"
echo "🔗 Jira URL: $JIRA_BASE_URL/browse/$ISSUE_KEY"
echo "🏁 [END] Jira Ticket Update Completed"
