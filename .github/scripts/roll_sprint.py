#!/usr/bin/env python3
"""Move the previous sprint's unfinished items on Team Violet Board 2.0 into the current sprint.

    roll_sprint.py [--dry-run]

Every item whose Sprint is the most recently completed iteration and whose Status is
not Done gets its Sprint set to the iteration that contains today. Items in Done keep
their Sprint. Re-running is a no-op once nothing is left in the previous sprint.

Needs `gh` authenticated with a token that has the `project` and `read:org` scopes.
"""
import json
import subprocess
import sys
from datetime import date, datetime, timedelta

OWNER = "notch8"
PROJECT_NUMBER = 84
SPRINT_FIELD = "Sprint"
STATUS_FIELD = "Status"
DONE = "Done"

PROJECT_QUERY = """
{ organization(login: "%s") { projectV2(number: %s) { id title
    field(name: "%s") { ... on ProjectV2IterationField { id configuration {
      iterations { id title startDate duration }
      completedIterations { id title startDate duration } } } } } } }
"""

ITEMS_QUERY = """
{ node(id: "%s") { ... on ProjectV2 { items(first: 100%s) {
  pageInfo { hasNextPage endCursor }
  nodes { id
    content {
      ... on Issue { number repository { nameWithOwner } }
      ... on PullRequest { number repository { nameWithOwner } }
      ... on DraftIssue { title } }
    sprint: fieldValueByName(name: "%s") { ... on ProjectV2ItemFieldIterationValue { iterationId } }
    status: fieldValueByName(name: "%s") { ... on ProjectV2ItemFieldSingleSelectValue { name } }
} } } } }
"""

SPRINT_MUTATION = """
mutation { updateProjectV2ItemFieldValue(input: {
  projectId: "%s", itemId: "%s", fieldId: "%s",
  value: { iterationId: "%s" } }) { projectV2Item { id } } }
"""


def gh_graphql(query):
    out = subprocess.run(["gh", "api", "graphql", "-f", "query=" + query],
                         check=True, stdout=subprocess.PIPE, text=True)
    return json.loads(out.stdout)["data"]


def start(iteration):
    return datetime.strptime(iteration["startDate"], "%Y-%m-%d").date()


def current_iteration(iterations):
    today = date.today()
    for iteration in iterations:
        if start(iteration) <= today < start(iteration) + timedelta(days=iteration["duration"]):
            return iteration
    return None


def previous_iteration(completed):
    return max(completed, key=start) if completed else None


def all_items(project_id):
    cursor = ""
    while True:
        page = gh_graphql(ITEMS_QUERY % (project_id, cursor, SPRINT_FIELD, STATUS_FIELD))
        page = page["node"]["items"]
        yield from page["nodes"]
        if not page["pageInfo"]["hasNextPage"]:
            return
        cursor = ', after: "%s"' % page["pageInfo"]["endCursor"]


def label(item):
    content = item["content"] or {}
    if "number" in content:
        return "%s#%s" % (content["repository"]["nameWithOwner"], content["number"])
    return "draft: %s" % content.get("title", "?")


def main():
    dry = "--dry-run" in sys.argv

    project = gh_graphql(PROJECT_QUERY % (OWNER, PROJECT_NUMBER, SPRINT_FIELD))
    project = project["organization"]["projectV2"]
    field = project.get("field")
    if not field:
        sys.exit("%s: no %r iteration field" % (project["title"], SPRINT_FIELD))

    current = current_iteration(field["configuration"]["iterations"])
    previous = previous_iteration(field["configuration"]["completedIterations"])
    if not current or not previous:
        sys.exit("%s: need both a current and a completed %s iteration" % (project["title"], SPRINT_FIELD))
    print("%s: %s -> %s" % (project["title"], previous["title"], current["title"]))

    verb = "would move" if dry else "moved"
    moved = skipped = 0
    for item in all_items(project["id"]):
        if (item["sprint"] or {}).get("iterationId") != previous["id"]:
            continue
        status = (item["status"] or {}).get("name")
        if status == DONE:
            skipped += 1
            continue
        print("%s %s [%s]" % (verb, label(item), status or "no status"))
        if not dry:
            gh_graphql(SPRINT_MUTATION % (project["id"], item["id"], field["id"], current["id"]))
        moved += 1
    print("%d %s, %d left in %s as %s" % (moved, verb, skipped, previous["title"], DONE))


if __name__ == "__main__":
    main()
