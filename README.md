# cloud-visitor-counter

A small serverless backend that powers the live stats in the footer of
[ammarhassan.dev](https://ammarhassan.dev) - built on AWS with Terraform, in
the spirit of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/).

It keeps two counters:

- **`visits`** — total visits to the site
- **`prius`** — how many times the Prius easter egg has been driven

Both live in DynamoDB and are incremented atomically, so concurrent hits never
race each other.

## Architecture

```
browser ──fetch──▶ API Gateway (HTTP API) ──▶ Lambda (Python 3.12) ──▶ DynamoDB
                                                                        { id: "visits" }
                                                                        { id: "prius"  }
```

- **DynamoDB** (on-demand) stores the counts — one item per counter.
- **Lambda** reads and increments via an atomic `ADD` expression.
- **API Gateway** (HTTP API) exposes it, with CORS locked to the site's origins.
- **IAM** grants the function least privilege — only `GetItem`/`UpdateItem` on
  this one table, plus permission to write its own logs.
- **Terraform** provisions every piece; tear it all down with one command.

## API

| Method | Path               | Response                      |
| ------ | ------------------ | ----------------------------- |
| `GET`  | `/counts`          | `{ "prius": N, "visits": N }` |
| `POST` | `/counts/{id}/hit` | `{ "<id>": N }` — atomic +1   |

Only `visits` and `prius` are accepted; anything else returns `400`.

## Stack

AWS (Lambda · API Gateway · DynamoDB · IAM) · Terraform · Python · pytest + moto

## Tests

The handler is unit-tested with DynamoDB mocked by [moto](https://github.com/getmoto/moto):

```bash
cd lambda
pip install -r requirements-dev.txt
pytest
```

## Deploy

Needs AWS credentials configured (`aws configure`) and Terraform installed.

```bash
cd infra
terraform init
terraform apply        # prints the API base URL
terraform destroy      # removes everything when you're done
```

## Notes

- Visits are counted **once per browser session** by the frontend — no cookies,
  no personal data, just a number.
- At portfolio traffic this runs comfortably inside the AWS free tier.
