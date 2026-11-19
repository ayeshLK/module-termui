// A model of one trip of a message around the loop, for the interactive diagram on "The update and view
// loop". It mirrors the counter in examples/counter/main.bal (`update` handles +, - and q; `view` shows the
// count and a hint) and knows nothing about the page: no DOM, no timers. The component maps its output to
// highlights and readouts, and the tests below pin it, including a check that the counter source still has
// the keys and the text this model assumes.

// The steps of the diagram, in the order a message passes through them.
export type StopId = 'outside' | 'queue' | 'loop' | 'update' | 'command' | 'view' | 'frame';

export const ALL_STOPS: readonly StopId[] = ['outside', 'queue', 'loop', 'update', 'command', 'view', 'frame'];

export interface Walk {
	key: string;
	stops: StopId[]; // the steps the message visits, in order
	countBefore: number;
	countAfter: number; // the state once `update` has run
	command: 'nothing' | 'quit()'; // what `update` returned
	quit: boolean; // the program ends at the command: no `view`, no frame
	updateLines: string[]; // what `update` did, for the readout
	frameBefore: string[];
	frameAfter: string[]; // what `view` returned (equal to frameBefore when the frame did not change)
	frameChanged: boolean; // false means the renderer writes nothing for this message
}

// The counter's `view`: the count, and a hint.
export function frameFor(count: number): string[] {
	return [`count: ${count}`, '+ and - change it, q quits'];
}

// The counter's `update`, for one key press. Any key other than +, - and q is ignored.
export function walk(count: number, key: string): Walk {
	const frameBefore = frameFor(count);
	let countAfter = count;
	let command: Walk['command'] = 'nothing';
	let updateLines: string[];
	if (key === '+') {
		countAfter = count + 1;
		updateLines = ['count += 1', 'returns ()'];
	} else if (key === '-') {
		countAfter = count - 1;
		updateLines = ['count -= 1', 'returns ()'];
	} else if (key === 'q') {
		command = 'quit()';
		updateLines = ['returns quit()'];
	} else {
		updateLines = ['not a key it knows', 'returns ()'];
	}
	const quit = command === 'quit()';
	const frameAfter = frameFor(countAfter);
	const frameChanged = !quit && frameAfter.some((line, i) => line !== frameBefore[i]);
	const stops: StopId[] = quit ? ['outside', 'queue', 'loop', 'update', 'command'] : [...ALL_STOPS];
	return { key, stops, countBefore: count, countAfter, command, quit, updateLines, frameBefore, frameAfter, frameChanged };
}

// Playing a walk through on a timer is movement the reader did not ask for, so it is offered only when the
// reader has not asked for reduced motion.
export function autoplayAllowed(prefersReducedMotion: boolean): boolean {
	return !prefersReducedMotion;
}
