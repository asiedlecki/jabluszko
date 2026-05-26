## Local Python Development Setup

Follow these steps to set up your local virtual environment:

1. **Install Poetry** on your system if you haven't already.
2. **Configure Poetry** to install the virtual environment within the project folder:
```bash
   poetry config virtualenvs.in-project true
   poetry install
   poetry shell
```
---

3. Daily Team Workflow

Keep these two habits in mind as a team to prevent environment drifting:

* **When adding new packages:** Anyone on the team who wants to install a new library must run `poetry add <package>`. They should then commit the updated `pyproject.toml` and `poetry.lock` files together.
* **When pulling code changes:** Whenever a teammate pulls changes from Git (`git pull`) and notices that `poetry.lock` has changed, they just need to run `poetry install`. Poetry will instantly sync their local `.venv` to match the repository.
   

