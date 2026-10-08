import { defineConfig } from 'vitepress'
export default defineConfig({
  title: 'Doclin',
  description: 'Open-source Mac dictation. Local processing by default.',
  outDir: 'dist',
  head: [['link', { rel: 'icon', type: 'image/png', href: '/images/logo.png' }]],
  themeConfig: {
    logo: '/images/logo.png',
    nav: [{ text: 'Home', link: '/' }, { text: 'Setup', link: '/setup' }, { text: 'Privacy', link: '/privacy' }],
    socialLinks: [{ icon: 'github', link: 'https://github.com/shawonibnkamal/doclin-macos' }],
    footer: { message: 'Main app MIT licensed. Bundled components retain their own licenses.', copyright: 'Doclin · Open-source Mac tools' }
  }
})
