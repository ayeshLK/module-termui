// Checks the internal links of the built site: every href and src that points into the site must resolve
// to a file in dist/, and every #fragment must match an id on the target page. External links are not
// followed. Run after `npm run build`; exits 1 and lists each broken link when there are any.
import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs';
import { join, posix, relative, sep } from 'node:path';

const dist = new URL('../dist/', import.meta.url).pathname;
const base = '/module-termui';

function* htmlFiles(dir) {
	for (const name of readdirSync(dir)) {
		const path = join(dir, name);
		if (statSync(path).isDirectory()) yield* htmlFiles(path);
		else if (name.endsWith('.html')) yield path;
	}
}

// The URL path a built file is served at, e.g. dist/tutorial/index.html -> /module-termui/tutorial/
function urlOf(file) {
	const rel = relative(dist, file).split(sep).join('/');
	return `${base}/${rel.replace(/index\.html$/, '')}`;
}

// The file that serves a URL path inside the site, or null when the path is outside the site.
function fileFor(urlPath) {
	if (urlPath !== base && !urlPath.startsWith(base + '/')) return null;
	let rel = decodeURIComponent(urlPath.slice(base.length)).replace(/^\//, '');
	if (rel === '' || rel.endsWith('/')) rel += 'index.html';
	let file = join(dist, rel);
	if (!existsSync(file) && existsSync(file + '/index.html')) file = join(file, 'index.html');
	return file;
}

const idCache = new Map();
function idsIn(file) {
	if (!idCache.has(file)) {
		const html = readFileSync(file, 'utf8');
		idCache.set(file, new Set([...html.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1])));
	}
	return idCache.get(file);
}

const broken = [];
let checked = 0;
for (const file of htmlFiles(dist)) {
	const page = urlOf(file);
	const html = readFileSync(file, 'utf8');
	for (const m of html.matchAll(/\s(?:href|src)="([^"]*)"/g)) {
		const raw = m[1];
		if (/^(https?:|mailto:|data:|javascript:|\/\/)/.test(raw) || raw === '') continue;
		const [pathPart, fragment] = raw.split('#');
		const urlPath = pathPart === '' ? page : posix.resolve(posix.dirname(page.endsWith('/') ? page + 'x' : page), pathPart) + (pathPart.endsWith('/') ? '/' : '');
		const target = fileFor(urlPath);
		if (target === null) {
			broken.push(`${page}: "${raw}" points outside the site (missing ${base}?)`);
			continue;
		}
		checked++;
		if (!existsSync(target)) {
			broken.push(`${page}: "${raw}" -> no file ${relative(dist, target)}`);
		} else if (fragment && target.endsWith('.html') && !idsIn(target).has(decodeURIComponent(fragment))) {
			broken.push(`${page}: "${raw}" -> no #${fragment} on the target page`);
		}
	}
}

if (broken.length > 0) {
	console.error(`${broken.length} broken link(s):`);
	for (const line of broken) console.error('  ' + line);
	process.exit(1);
}
console.log(`links ok: ${checked} internal links checked`);
