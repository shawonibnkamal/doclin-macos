import { defineConfig } from 'vitepress'
export default defineConfig({
  title: 'Doclin',
  description: 'Open-source Mac dictation. Local processing by default.',
  outDir: 'dist',
  appearance: 'force-dark',
  head: [['link', { rel: 'icon', type: 'image/png', href: '/images/logo.png' }]],
  themeConfig: {
    logo: '/images/logo.png',
    nav: [{ text: 'Privacy', link: '/privacy' }],
    socialLinks: [{ icon: 'github', link: 'https://github.com/shawonibnkamal/doclin-macos' }],
    footer: { message: 'Free and open source.', copyright: 'Doclin' }
  }
})
