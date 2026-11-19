// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// The site is served from https://ayeshlk.github.io/module-termui/. A custom domain would change
// only `site` and `base`.
export default defineConfig({
	site: 'https://ayeshlk.github.io',
	base: '/module-termui',
	integrations: [
		starlight({
			title: 'termui',
			description:
				'Build agent-style terminal apps in Ballerina: streaming output, a live region, and approval prompts that stay well-behaved in pipes and CI.',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/ayeshLK/module-termui' }],
			sidebar: [
				{ label: 'Start here', items: [{ autogenerate: { directory: 'start' } }] },
				{ label: 'Concepts', items: [{ autogenerate: { directory: 'concepts' } }] },
				{ label: 'Best practices', items: [{ autogenerate: { directory: 'best-practices' } }] },
				{ label: 'Tutorial', items: [{ autogenerate: { directory: 'tutorial' } }] },
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
