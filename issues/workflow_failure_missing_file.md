## Issue: Workflow Failure Due to Missing File

### Description
The workflow has failed due to a missing file `environments/mnms01_test.yaml`. This issue was observed in the job [#47630398795](https://github.com/v1vhm/resource-group-vending/actions/runs/16815265109/job/47630398795) of the GitHub Actions workflow.

### Error Message
```
environments/mnms01_test.yaml: No such file or directory
```

### Recommendation
It is recommended to:
1. Add the missing `environments/mnms01_test.yaml` file to the repository.
2. Check if this file is generated dynamically before it is accessed in the workflow.

### Reference
Job Commit: [0af281b6664006e3395b5bf1c55339d69fb7f169](https://github.com/v1vhm/resource-group-vending/commit/0af281b6664006e3395b5bf1c55339d69fb7f169)