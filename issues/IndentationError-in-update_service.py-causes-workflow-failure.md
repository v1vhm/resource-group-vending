# IndentationError in update_service.py causes workflow failure

The workflow [Associate Service](https://github.com/v1vhm/resource-group-vending/actions/runs/17066975826/job/48386354448) failed due to an IndentationError in update_service.py at ref 0ff344af557fdd92cbdc2fb7a9d794b3917576a2.

Error message:
```
IndentationError: expected an indented block after 'with' statement on line 6
```

Please fix the indentation after the 'with' statement, e.g.:
```python
with open(env_file) as f:
    data = yaml.safe_load(f) or {}
```

Ensure all code under the 'with' statement is properly indented. This will allow the workflow to complete successfully.