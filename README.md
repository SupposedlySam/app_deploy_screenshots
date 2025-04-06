Welcome to App Deploy Screenshots!

This package is meant to help you automate your app deployment process by taking screenshots of your app for upload to the Apple App Store and Google Play Store.

# How does it work?

1. Similar to an E2E test, set up your app with mock data for each scenario you want to create a screenshot for.
2. Add configuration for all device screen sizes and densities you want to upload to the app stores.
3. Run everything locally to ensure your screenshots will turn out the way you want them.
4. Create a step in your CI to do this for you so you can ensure your app store screenshots are always up to date.

# Getting Started

Write a test and use the createAllByPlatformAndDevice or appDeployScreenshot functions. Once you run your test, use the screenshots in the generated `app_deploy_screenshots` directory to upload to the app stores.

## Set up mock data

TODO

## Configure Devices

TODO

## Run Locally

TODO

## Build Into Your CI (optional)

TODO
