import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { ALL_STOPS, autoplayAllowed, frameFor, walk } from './loop-walk.ts';

test('+ goes through every step, increments, and changes the frame', () => {
	const w = walk(0, '+');
	assert.deepEqual(w.stops, ['outside', 'queue', 'loop', 'update', 'command', 'view', 'frame']);
	assert.equal(w.countBefore, 0);
	assert.equal(w.countAfter, 1);
	assert.equal(w.command, 'nothing');
	assert.equal(w.quit, false);
	assert.deepEqual(w.frameBefore, ['count: 0', '+ and - change it, q quits']);
	assert.deepEqual(w.frameAfter, ['count: 1', '+ and - change it, q quits']);
	assert.equal(w.frameChanged, true);
	assert.deepEqual(w.updateLines, ['count += 1', 'returns ()']);
});

test('- decrements, also below zero', () => {
	const w = walk(0, '-');
	assert.equal(w.countAfter, -1);
	assert.equal(w.frameChanged, true);
	assert.equal(walk(5, '-').countAfter, 4);
});

test('the state is whatever it is passed: it is not remembered between walks', () => {
	assert.equal(walk(5, '+').countAfter, 6);
	assert.equal(walk(41, '+').frameAfter[0], 'count: 42');
});

test('a key the counter ignores visits every step but changes nothing, so nothing is written', () => {
	const w = walk(3, 'x');
	assert.deepEqual(w.stops, [...ALL_STOPS]);
	assert.equal(w.countAfter, 3);
	assert.equal(w.command, 'nothing');
	assert.deepEqual(w.frameAfter, w.frameBefore);
	assert.equal(w.frameChanged, false);
	assert.deepEqual(w.updateLines, ['not a key it knows', 'returns ()']);
});

test('q ends at the command: quit() is returned, and there is no view and no frame', () => {
	const w = walk(2, 'q');
	assert.deepEqual(w.stops, ['outside', 'queue', 'loop', 'update', 'command']);
	assert.equal(w.command, 'quit()');
	assert.equal(w.quit, true);
	assert.equal(w.countAfter, 2);
	assert.equal(w.frameChanged, false);
});

test('the steps are always visited in the order of the diagram, with none repeated', () => {
	for (const key of ['+', '-', 'x', 'q', '']) {
		const stops = walk(0, key).stops;
		assert.deepEqual(stops, ALL_STOPS.filter((s) => stops.includes(s)), `order for "${key}"`);
		assert.equal(new Set(stops).size, stops.length);
	}
});

test('autoplay is not offered when the reader asks for reduced motion', () => {
	assert.equal(autoplayAllowed(true), false);
	assert.equal(autoplayAllowed(false), true);
});

// The model mirrors examples/counter/main.bal. If the counter changes, this fails and says what to update.
test('the counter source still has the keys and the text this model assumes', () => {
	const source = readFileSync(resolve(process.cwd(), '..', 'examples/counter/main.bal'), 'utf8');
	const where = 'examples/counter/main.bal changed: update site/src/lib/loop-walk.ts to match';
	assert.match(source, /message\.key == "\+"/, `${where} (the + key)`);
	assert.match(source, /self\.count \+= 1/, `${where} (what + does)`);
	assert.match(source, /message\.key == "-"/, `${where} (the - key)`);
	assert.match(source, /self\.count -= 1/, `${where} (what - does)`);
	assert.match(source, /message\.key == "q"/, `${where} (the q key)`);
	assert.match(source, /return termui:quit\(\)/, `${where} (what q returns)`);
	const [line1, line2] = frameFor(0);
	assert.ok(source.includes('"count: " + self.count.toString()'), `${where} (the count line of the view: ${line1})`);
	assert.ok(source.includes(line2), `${where} (the hint line of the view: ${line2})`);
});
