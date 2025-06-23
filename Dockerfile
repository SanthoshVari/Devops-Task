
FROM python:3.9-slim as builder

WORKDIR /install

COPY app.py .


RUN pip install --prefix=/install --no-cache-dir flask


FROM python:3.9-slim


RUN useradd --create-home --shell /bin/bash appuser


WORKDIR /home/appuser/app
COPY --from=builder /install /usr/local
COPY app.py .


USER appuser

EXPOSE 5000
CMD ["python", "app.py"]