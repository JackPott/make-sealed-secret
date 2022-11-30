# Make a Kubernetes Sealed Secret

Simple bash script to automate creating a [Sealed Secret](https://github.com/bitnami-labs/sealed-secrets) in Kubernetes. 

## How to use

- Put your secrets in a secrets.env file somewhere (ideally somewhere there is no risk
  of you checking them in)
- Run `make-secret.sh --secret-name <my_secret_name> secrets.env
- This will create a SealedSecret.yaml in the current directory which you can apply or
  use as part of your kustomization.yaml
- Note it will apply it to <my_secret_name> namespace by default

## Complex example

```sh
make-secret.sh \
  --namespace my_namespace \
  --secret-name hushhush \
  --temp-secret inconspicuous.file \
  --output-dir ~/dev/manifests/myapp \
  --output-name Mystery.yaml
  ~/topsecret/passwords.env
```

- It will look for a .env at `~/topsecret/passwords.env`
- It will make its temporary Secret file at `~/dev/manifests/myapp/inconspicuous.file`
- The finished SealedSecret yaml will be placed at `~/dev/manifests/myapp/Mystery.yaml`
- Once applied it will unpack a Secret called `hushhush` in the namespace `my_namespace`

## Cluster wide secrets

- `make-secret.sh --cluster --secret-name docker_creds file.env`
- This creates a SealedSecret which can be deployed multiple times in the cluster
- For example you could use this as part of your base kustomisation.yaml so it is
  deployed into every namespace
- If you `kubectl apply -f SealedSecret.yaml` it won't deploy it to every namespace
  on its own, only `default`

## Turning general files into secrets

- Rather than expecting a key-value pair file this would take a whole file (like a
  certificate PEM) and encode it as a Sealed Secret.
- This will often be mounted into a container as a file (rather than env vars)

```sh
  ./make-secret.sh \
    --namespace backend \
    --secret-name backend-private-key \
    --from-file \
    sample.pem
```

## Easy mode

```sh
  ./make-secret.sh --secret-name api-server secret.env
```

- If you specify the minimum of options, this is how it will behave:
- Converts the .env file at `./secret.env` to a temporary Secret at `./secret.yaml`
- Encrypts and creates the Sealed Secret at `./SealedSecret.yaml`
- Once applied it will unpack a Secret called `api-server` in the namespace `api-server`
- Removes the temp `./secret.yaml`, but leaves the original `secret.env` in place (Don't check this in!)

## Todo

- [ ] Allow specifying a local public key so auth+VPN the cluster isn't required

## Credits

Built on top of **Maciej Radzikowski's** excellent [Minimal Safe Bash Template](https://betterdev.blog/minimal-safe-bash-script-template/)
