/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./website_user/templates/**/*.html",
    "./website_dev/templates/**/*.html",
    "./website_user/static/js/**/*.js",
    "./website_dev/static/js/**/*.js",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
