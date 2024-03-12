# SAAS Backend Starter Template

**You can check out my project [IndiePitcher](https://indiepitcher.com) for an example of a SAAS with a backend written in Swift, using this template.**

This is an extension of Vapor's [starter template](https://github.com/vapor/template) to get the backend for your next SAAS off the ground. Or if you're jsut curious about server-side Swift and Vapor, and would like to see some real code.

It takes care of the tedious tasks for you, **user management, sending emails, analytics, error logging**...

Every SAAS needs to handle user sign up, and if your service takes off, you'll start being asked by customers how they can invite their colleagues. This ends up being a huge pain if everything is tied to a user profile instead of an organization unit. That's why this template includes a complete organization management with 3 levels of user permission. You can create a default org with a user profile during sign up that's hidden from the user, that's fine, and you are ready for to future.

- This repo will be expanded and kept up to date with the latest Swift and Vapor releases, feel free to give it a star and/or subscribe for updates.
- **I'm working on a course explaining everything in in a very detailed way. Scroll down to learn more and [join the waitlist](https://tally.so/r/wbdgqg).**

## Overview
- **JWT-based user authentication using Firebase**
  - Firebase provides a very generous offering of 50,000 monthly active users for free
  - You can swap firebase for a different provider with little effort
- **Grouping users into organisations with user roles**
  - Think GitHub or Figma organization you have for your company
- **Using PostgreSQL as database**
  - Swappable for a different database supported by Vapor’s ORM framework Fluent, I’d recommend sticking with PostgreSQL though
- **Sending emails using SMTP**
  - Send automated emails such as "You've been added to RockerAI organization as an admin."
  - Can be swapped for Sendgrid or another solution
- **Tracking of server events to Mixpanel**
  - Tracking important events, such as new user sign up, is more reliable to track from the backend than
  - Mixpanel offers a generous free tier and is realtime.
- **Logging of errors to Sentry**
  - Automatic logging of erros and warning
  - Sentry offers a generous free plan to get you started
- **All dockerized and deployable pretty much anywhere**
  - AWS, DigitalOcean, ...
- **Tests for everything**
  - Don’t worry about breaking the production, we have unit tests.


 
## How to Use
- Clone this repo to use it as a building block for your project
- You'll need a postgre database. You can 
- When cloned, create `.env` file and fill in following info to be able to run the app against a local database.
  - ```
    FIREBASE_PROJECT_ID=your-firebase-project-id
    ```
    - This is enough to run the project locally. When deploying to production, you'll want to add the database connection keys, as well as optionally your mixpanel and sentry credentials
    - You can copy the `FIREBASE_PROJECT_ID` from `.env.testing` to try things out, but please do create your own firebase project.
- Set up your local dev environment, you need to spin up a database. An easy way is by downloading [Docker](https://www.docker.com) and typing in following commands
  - `docker-compose build`
  - `docker-compose up db` starts a local database to develop against
  - `docker-compose up db-test` starts a local database to run init tests against (this is a separate database so you don't wipe your data when running unit tests)
  - `docker-compose down` to shut the databases down, or just kill the docker app
- Running the project locally and running the unit tests should now work



## Deployment
You can deploy your backend anywhere that supports Docker. An obvious choice for many people would be AWS, I'm personally a fan of [Digital Ocean's App Platform](https://m.do.co/c/9e21fc78af92). 
You can also check out fly.io since they offer a free tier, or good old Heroku using the swift buildpack.



## Want to Learn More?
I'm hard at work working on a video course providing a detailed walk through of this template and Vapor framework in general. If you're interested, or would just like to support further development, you can [join the waitlist](https://forms.indiepitcher.com/BdmkCi).

I'd also encourage you to join the [vapor discord](https://discord.gg/vapor). Feel free to DM me there.

