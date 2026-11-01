. "$LAB_LIB"
f=checkout-app.yaml
[ -f "$f" ] || fail "checkout-app.yaml does not exist."
[ -n "$(yaml_get "$f" 'd && typeof d === "object" ? 1 : ""')" ] || fail "checkout-app.yaml is not valid YAML."
[ "$(yaml_get "$f" 'd.kind')" = "Application" ] && [ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "checkout" ] || fail "Keep it an Application named checkout."
[ "$(yaml_get "$f" 'd.apiVersion')" = "argoproj.io/v1alpha1" ] || fail "apiVersion is still wrong: the Application API is argoproj.io/v1alpha1."
[ "$(yaml_get "$f" 'd.metadata.namespace')" = "argocd" ] || fail "metadata.namespace should be argocd, the namespace Argo CD watches."
