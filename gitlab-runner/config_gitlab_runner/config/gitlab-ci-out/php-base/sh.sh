vi Dockerfile
buildah build -t container.local.your-domain-name.com/base/php:v1 .
buildah login -u username -p rGosNs0esVcioCoHoeEG container.local.your-domain-name.com
buildah push container.local.your-domain-name.com/base/php:v1