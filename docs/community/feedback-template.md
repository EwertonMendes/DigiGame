# Player feedback and internal triage

Players should not need a GitHub account. Ask them to paste one of these short templates into the Discord `feedback` or `bugs` channel. A maintainer transfers actionable items to GitHub Issues.

## General feedback

```text
Build / device:
Moment or feature:
What were you trying to decide or understand?
What did you notice?
What would have made the decision clearer?
Screenshot or video (optional):
```

## Bug report

```text
Build / device / browser:
What were you trying to do?
What happened?
What did you expect?
Can you reproduce it? If yes, list the steps:
Screenshot or video (optional):
```

## Session debrief

```text
Did you finish the mission and return to the hub? Yes / No
Where did you stop or get stuck?
Which decision felt most tactical?
Which screen or rule was least clear?
Would you test a second build? Yes / Maybe / No — why?
```

## Maintainer triage

Classify every useful report before copying it to an internal issue:

- **Blocker**: prevents the main flow or loses progress.
- **High**: a major system works incorrectly with no practical workaround.
- **Medium**: confusing or incorrect behavior with a workaround.
- **Low**: polish, copy, or minor usability problem.
- **Design signal**: not a defect, but repeated behavior or misunderstanding that may justify a design change.

An internal issue should contain the source build, environment, reproduction steps, expected/actual result, evidence, severity, and a link back to the Discord thread when appropriate. Never copy personal information that is not needed to solve the problem.

## Closing the loop

After each test round, publish a short outcome grouped into four headings:

1. **You said** — summarize the repeated signal without naming people unless they asked for credit.
2. **I observed** — add completion data, recordings, or reproduction results.
3. **Changed** — list changes already made and their target build.
4. **Not changing yet** — explain the tradeoff, missing evidence, or higher-priority dependency.
