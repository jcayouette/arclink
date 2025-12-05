import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Arclink',
  tagline: 'Resilient, mobile tactical communications. Dependable anywhere.',
  favicon: 'img/favicon.ico',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  headTags: [
    {
      tagName: 'meta',
      attributes: {
        name: 'algolia-site-verification',
        content: '3D387560A325CF1D',
      },
    },
  ],

  // Set the production url of your site here
  url: process.env.NODE_ENV === 'production' ? 'https://jcayouette.github.io' : 'http://localhost:3000',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: process.env.NODE_ENV === 'production' ? '/arclink/' : '/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'jcayouette', // Usually your GitHub org/user name.
  projectName: 'arclink', // Usually your repo name.

  onBrokenLinks: 'throw',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/jcayouette/arclink/tree/main/docs/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Social card for link previews (Twitter, Discord, etc.)
    image: 'img/arclink-social-card.png',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    mermaid: {
      theme: {light: 'base', dark: 'base'},
      options: {
        themeVariables: {
          primaryTextColor: '#000',
          secondaryTextColor: '#000',
          tertiaryTextColor: '#000',
          lineColor: '#333',
          textColor: '#000',
          mainBkg: '#e8e8e8',
          secondBkg: '#fff',
          tertiaryBkg: '#f5f5f5',
          primaryColor: '#d4e9f7',
          secondaryColor: '#c8e6c9',
          tertiaryColor: '#ffccbc',
        },
        themeCSS: `
          [data-theme='dark'] .mermaid {
            --mermaid-primary-text: #fff !important;
            --mermaid-secondary-text: #fff !important;
            --mermaid-tertiary-text: #fff !important;
            --mermaid-text: #fff !important;
          }
          [data-theme='dark'] .mermaid .nodeLabel,
          [data-theme='dark'] .mermaid .edgeLabel {
            color: #fff !important;
            fill: #fff !important;
          }
          [data-theme='dark'] .mermaid .node rect,
          [data-theme='dark'] .mermaid .node circle,
          [data-theme='dark'] .mermaid .node polygon {
            fill: #2d3748 !important;
            stroke: #4a8fc7 !important;
          }
          [data-theme='dark'] .mermaid .cluster rect {
            fill: #1f2937 !important;
            stroke: #4a8fc7 !important;
          }
          [data-theme='dark'] .mermaid .edgeLabel rect {
            fill: #374151 !important;
          }
          [data-theme='dark'] .mermaid .edgePath .path {
            stroke: #4a8fc7 !important;
          }
          .mermaid .cluster-label,
          .mermaid .cluster text {
            fill: #000 !important;
            color: #000 !important;
            font-weight: bold !important;
          }
          [data-theme='dark'] .mermaid .cluster-label,
          [data-theme='dark'] .mermaid .cluster text {
            fill: #fff !important;
            color: #fff !important;
            font-weight: bold !important;
          }
        `,
      },
    },
    algolia: {
      // The application ID provided by Algolia
      appId: 'WWLA8H7PS8',
      // Public API key: it is safe to commit it
      apiKey: 'bfef6bb1903659a03f763542280bb330',
      indexName: 'arclink',
      // Optional: see doc section below
      contextualSearch: false,
      // Optional: Algolia search parameters
      searchParameters: {},
      // Optional: path for search page that enabled by default (`false` to disable it)
      searchPagePath: 'search',
    },
    navbar: {
      title: 'Arclink',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          href: 'https://github.com/jcayouette/arclink',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Getting Started',
              to: '/docs/intro',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/jcayouette/arclink',
            },
            {
              label: 'OpenTAK Server',
              href: 'https://github.com/brian7704/OpenTAKServer',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Arclink Project. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
