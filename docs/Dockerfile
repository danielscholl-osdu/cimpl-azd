FROM python:3.12-slim

RUN pip install --no-cache-dir zensical mkdocs-material

WORKDIR /docs
EXPOSE 8000

ENTRYPOINT ["zensical"]
CMD ["serve", "--dev-addr", "0.0.0.0:8000"]
