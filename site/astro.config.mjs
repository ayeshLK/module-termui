// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// The site is served from https://ayeshlk.github.io/module-termui/. A custom domain would change
// only `site` and `base`.
const base = '/module-termui';

export default defineConfig({
	site: 'https://ayeshlk.github.io',
	base,
	// The harness tutorial moved under /tutorial/harness/. The old step addresses still work. Astro does not add
	// the base to a redirect's target, so it is added here.
	redirects: {
		'/tutorial/01-counter': `${base}/tutorial/harness/01-counter/`,
		'/tutorial/02-prompt': `${base}/tutorial/harness/02-prompt/`,
		'/tutorial/03-streaming': `${base}/tutorial/harness/03-streaming/`,
		'/tutorial/04-status': `${base}/tutorial/harness/04-status/`,
		'/tutorial/05-approval': `${base}/tutorial/harness/05-approval/`,
		'/tutorial/06-testing': `${base}/tutorial/harness/06-testing/`,
	},
	integrations: [
		starlight({
			title: 'termui',
			customCss: ['./src/styles/diagrams.css'],
			components: { Hero: './src/components/Hero.astro' },
			description:
				'A general-purpose terminal UI library for Ballerina.',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/ayeshLK/module-termui' }],
			sidebar: [
				{ label: 'Start here', items: [{ autogenerate: { directory: 'start' } }] },
				{ label: 'Concepts', items: [{ autogenerate: { directory: 'concepts' } }] },
				{ label: 'Best practices', items: [{ autogenerate: { directory: 'best-practices' } }] },
				{
					label: 'Tutorials',
					items: [
						{ label: 'Choose a tutorial', slug: 'tutorial' },
						{ label: 'A to-do list', items: [{ autogenerate: { directory: 'tutorial/todo-list' } }] },
						{ label: 'An agent harness', items: [{ autogenerate: { directory: 'tutorial/harness' } }] },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'API on Ballerina Central', link: 'https://central.ballerina.io/ayesha/termui/1.0.0' },
						{ label: 'Compatibility policy', link: 'https://github.com/ayeshLK/module-termui/blob/main/COMPATIBILITY.md' },
						{ label: 'Changelog', link: 'https://github.com/ayeshLK/module-termui/blob/main/CHANGELOG.md' },
					],
				},
			],
		}),
	],
});
