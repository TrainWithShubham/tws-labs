// Wrong-but-plausible answers for the Kubernetes labs' checks: the validator proves "fails before, passes after the solution",
// these prove the checks also reject near-misses and accept valid alternatives. They need only bash and node (yaml_get).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const ROOT = path.join(__dirname, '..', '..');
const LIB = path.join(ROOT, 'labs', 'lib.sh');
const hasBash = spawnSync('bash', ['-c', 'true']).status === 0;

function grade(lab, step, files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'k8s-check-'));
  fs.mkdirSync(path.join(dir, 'app'));
  for (const [name, text] of Object.entries(files)) fs.writeFileSync(path.join(dir, 'app', name), text);
  const r = spawnSync('bash', [path.join(ROOT, 'labs', 'kubernetes', lab, 'checks', `${step}.sh`)], { cwd: dir, env: { ...process.env, LAB_LIB: LIB, LAB_HISTORY: '/dev/null' }, encoding: 'utf8' });
  return { pass: r.status === 0, message: (r.stdout || '').split('\n')[0] };
}
const b64 = (s) => Buffer.from(s).toString('base64');
const secret = (value) => `apiVersion: v1\nkind: Secret\nmetadata:\n  name: db-credentials\ntype: Opaque\ndata:\n  DB_PASSWORD: ${value}\n`;
const dep = (extra = {}) => `apiVersion: ${extra.api || 'apps/v1'}\nkind: Deployment\nmetadata:\n  name: shop\nspec:\n  selector:\n    matchLabels:\n      app: ${extra.sel || 'shop'}\n  template:\n    metadata:\n      labels:\n        app: ${extra.tpl || 'shop'}\n    spec:\n      containers:\n        - name: shop\n          image: ${extra.image || 'nginx:1.27'}\n          ports:\n            - containerPort: 8080\n${extra.more || ''}`;
const svc = (target) => `apiVersion: v1\nkind: Service\nmetadata:\n  name: shop\nspec:\n  selector:\n    app: shop\n  ports:\n    - port: 80\n      targetPort: ${target}\n`;
const t = (name, fn) => test(name, { skip: !hasBash && 'needs bash' }, fn);

t('secret: plain text, an encoding with a trailing newline, and the wrong value are rejected; quoted or unquoted base64 is accepted', () => {
  const g = (v) => grade('configs-and-secrets', 'secret', { 'secret.yaml': secret(v) }).pass;
  assert.equal(g('s3cr3t'), false, 'not encoded');
  assert.equal(g(b64('s3cr3t\n')), false, 'echo without -n');
  assert.equal(g(b64('hunter2')), false, 'wrong password');
  assert.equal(g(b64('s3cr3t')), true);
  assert.equal(g(`"${b64('s3cr3t')}"`), true, 'quoted');
  assert.equal(grade('configs-and-secrets', 'secret', { 'secret.yaml': secret(b64('s3cr3t')).replace('type: Opaque', 'type: kubernetes.io/basic-auth') }).pass, false, 'wrong type');
});

t('config volume: the mount must use the volume\'s own name, whatever the learner called it', () => {
  const pod = (volName, mountName, path_) => dep({ more: `          volumeMounts:\n            - name: ${mountName}\n              mountPath: ${path_}\n      volumes:\n        - name: ${volName}\n          configMap:\n            name: app-config\n` });
  const g = (v, m, p) => grade('configs-and-secrets', 'config-volume', { 'deployment.yaml': pod(v, m, p) }).pass;
  assert.equal(g('config', 'config', '/etc/app'), true);
  assert.equal(g('settings', 'settings', '/etc/app'), true, 'any volume name works');
  assert.equal(g('config', 'other', '/etc/app'), false, 'mount names a volume that does not exist');
  assert.equal(g('config', 'config', '/etc/other'), false, 'wrong path');
});

t('selector: either side can be changed to make them agree, a mismatch or a missing label is rejected', () => {
  const g = (sel, tpl) => grade('fix-the-manifest', 'selector', { 'deployment.yaml': dep({ sel, tpl }) }).pass;
  assert.equal(g('shop', 'shop'), true);
  assert.equal(g('shop-web', 'shop-web'), true, 'changing both is fine');
  assert.equal(g('shop', 'shop-web'), false);
});

t('service port: the Service must target the container\'s port and keep its own port', () => {
  const g = (target) => grade('fix-the-manifest', 'service-port', { 'deployment.yaml': dep(), 'service.yaml': svc(target) }).pass;
  assert.equal(g(8080), true);
  assert.equal(g(80), false, 'the broken starting value');
  assert.equal(grade('fix-the-manifest', 'service-port', { 'deployment.yaml': dep(), 'service.yaml': svc(8080).replace('port: 80\n', 'port: 8080\n') }).pass, false, 'changing the Service\'s own port is not the fix');
});

t('image tag: latest, no tag and another version are all rejected', () => {
  const g = (image) => grade('fix-the-manifest', 'image-tag', { 'deployment.yaml': dep({ image }) }).pass;
  assert.equal(g('nginx:1.27'), true);
  assert.equal(g('nginx'), false);
  assert.equal(g('nginx:latest'), false);
  assert.equal(g('nginx:1.26'), false);
});

t('api version: the removed beta version is rejected', () => {
  assert.equal(grade('fix-the-manifest', 'api-version', { 'deployment.yaml': dep({ api: 'apps/v1beta1' }) }).pass, false);
  assert.equal(grade('fix-the-manifest', 'api-version', { 'deployment.yaml': dep() }).pass, true);
});
