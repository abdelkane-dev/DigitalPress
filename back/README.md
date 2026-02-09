# DigitalPress Backend (Boilerplate)

This folder contains a minimal Django + DRF boilerplate for the DigitalPress platform.

Quick start (development):

1. Copy `.env.example` to `.env` and edit values.
2. Create a virtualenv and install requirements:

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

3. Run migrations and seed data:

```powershell
python manage.py migrate
python seed.py
python manage.py runserver
```

Swagger: `http://localhost:8000/swagger/`

Docker: use the top-level `docker-compose.yml` to run `db` + `web`.
