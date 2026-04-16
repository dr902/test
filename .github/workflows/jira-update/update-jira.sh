#!/bin/bash
set -e

# Calculate Duration from variables passed from pipeline
DURATION=$((END_TIME - START_TIME))
[ "$DURATION" -lt 60 ] && DURATION=60

# Helper function for transitions
get_transition_id() {
  curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
    "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions" \
    | jq -r ".transitions[] | select(.name==\"$1\") | .id"
}

if [ "$JOB_STATUS" == "success" ]; then
    echo "Updating Jira: SUCCESS (Duration: $DURATION seconds)"

    # Update Original Estimate
    curl -s -X PUT -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY" -d "{\"fields\": {\"timeoriginalestimate\": $DURATION}}"

    # Log Work
    curl -s -X POST -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/worklog" -d "{\"timeSpentSeconds\": $DURATION}"

    # Transition to Done
    T_ID=$(get_transition_id "Done")
    curl -s -X POST -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions" -d "{\"transition\": {\"id\": \"$T_ID\"}}"

      
else
    echo "Updating Jira: FAILURE (Duration: $DURATION seconds)"
    
    ERROR_MSG="Deployment failed. Logs: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"

    # Update Estimate and Description
    curl -s -X PUT -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY" \
      -d "{
        \"fields\": {
          \"timeoriginalestimate\": $DURATION,
          \"description\": {
            \"type\": \"doc\", \"version\": 1,
            \"content\": [{\"type\": \"paragraph\", \"content\": [{\"type\": \"text\", \"text\": \"$ERROR_MSG\"}]}]
          }
        }
      }"

    # Transition to Rejected
    T_ID=$(get_transition_id "Rejected")
    curl -s -X POST -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Content-Type: application/json" \
      "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY/transitions" -d "{\"transition\": {\"id\": \"$T_ID\"}}"
fi
