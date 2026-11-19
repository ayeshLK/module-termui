// The idle backoff schedule, computed from the source it describes, so the chart on "Idle cost" cannot drift
// from the code: the shortest sleep and the ceiling are the defaults of `pollInterval` and `maxPollInterval`
// in ballerina/engine.bal, and the number of empty checks per step is EMPTY_CHECKS_PER_STEP in
// ballerina/backoff.bal. Each is read with a strict pattern, and the site build fails with a message naming
// the file and the constant when one is not found (a rename, a move), instead of drawing a wrong chart.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const ENGINE = 'ballerina/engine.bal';
const BACKOFF = 'ballerina/backoff.bal';

function read(file: string, pattern: RegExp, what: string): number {
	const text = readFileSync(resolve(process.cwd(), '..', file), 'utf8');
	const match = pattern.exec(text);
	if (!match) {
		throw new Error(`BackoffChart: could not find ${what} in ${file}; the chart reads it from the source (pattern ${pattern}). Update site/src/lib/backoff.ts if it was renamed or moved.`);
	}
	return Number(match[1]);
}

export interface Step {
	sleep: number; // seconds
	from: number; // seconds of idleness when this sleep starts
	to: number; // seconds of idleness when it ends (the last step is open-ended: its `to` equals `from`)
}

export interface Schedule {
	base: number; // seconds
	ceiling: number; // seconds
	checksPerStep: number;
	steps: Step[]; // the doubling steps, then the ceiling
	reachedAt: number; // seconds of idleness at which the ceiling is reached
}

export function backoffSchedule(): Schedule {
	const base = read(ENGINE, /^\s*decimal\s+pollInterval\s*=\s*([0-9.]+);/m, 'the default of pollInterval');
	const ceiling = read(ENGINE, /^\s*decimal\s+maxPollInterval\s*=\s*([0-9.]+);/m, 'the default of maxPollInterval');
	const checksPerStep = read(BACKOFF, /^const\s+int\s+EMPTY_CHECKS_PER_STEP\s*=\s*(\d+);/m, 'EMPTY_CHECKS_PER_STEP');
	if (!(base > 0 && ceiling > base && checksPerStep > 0)) {
		throw new Error(`BackoffChart: unexpected values from the source (pollInterval ${base}, maxPollInterval ${ceiling}, ${checksPerStep} checks per step)`);
	}
	// the rule of backOff(): the sleep doubles after every `checksPerStep` empty checks, and never passes the ceiling
	const steps: Step[] = [];
	let sleep = base;
	let t = 0;
	while (sleep < ceiling) {
		const to = t + checksPerStep * sleep;
		steps.push({ sleep, from: t, to });
		t = to;
		sleep = Math.min(sleep * 2, ceiling);
	}
	steps.push({ sleep: ceiling, from: t, to: t });
	return { base, ceiling, checksPerStep, steps, reachedAt: t };
}
