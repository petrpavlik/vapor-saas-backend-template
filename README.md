# SAAS Backend Starter Template

This is an extension of Vapor's [starter template](https://github.com/vapor/template) with added support for **user management, sending emails, analytics, error logging**... to get the backend for your (SaaS/startup/project) off the ground. Or if you're jsut curious about server-side Swift and Vapor, and would like to see some real code.

---

## !!NEW!!: Get Access to a Complete Backend Codebase

This code is extracted from my startup [IndiePitcher](https://indiepitcher.com) and free to use under a permissive MIT licence. If youre interested in additional features, such as Stripe purchases, uploading files (to S3), and many (seriously) more, you can purchase access to IndiePitcher's source code to get access to the source code of a complex backend written in Swift using Vapor that is deployed in production and making money. [Read more and purchase here](https://github.com/petrpavlik/vapor-saas-backend-template/blob/main/PURCHASE_COMPLETE_SOURCE_CODE.md).

---

## Why do I Need This?

Every SaaS needs to handle user sign up, and if your service takes off, you'll start being asked by customers how they can invite their colleagues. This ends up being a huge pain if everything is tied to a user profile instead of an organization unit. That's why this template includes a complete organization management with 3 levels of user permission. You can create a default org with a user profile during sign up that's hidden from the user, that's fine, and you are ready for to future.

## Overview
- **JWT-based user authentication using Firebase**
  - Firebase provides a very generous offering of 50,000 monthly active users for free
  - You can swap firebase for a different provider
- **Grouping users into organisations with user roles**
  - Think GitHub or Figma organization you have for your company
- **Using a database**
  - SQLite be default to get you strted easily
  - Swappable for a different database supported by Vapor’s ORM framework Fluent, such as PostgreSQL or MySQL.
- **Sending emails using [IndiePitcher](https://indiepitcher.com)**
  - Send automated emails such as "You've been added to RockerAI organization as an admin."
  - Can be swapped for Sendgrid, Resend, SMTP, or another solution
- **Tracking of server events to Mixpanel**
  - Tracking important events, such as new user sign up, is more reliable to track from the backend than
  - Mixpanel offers a generous free tier and is realtime.
- **Logging of errors to Sentry**
  - Automatic logging of erros and warning
  - Sentry offers a generous free plan to get you started
- **All dockerized and deployable pretty much anywhere**
  - AWS, DigitalOcean, ...
- **Unit/Integration tests**
  - Provided code is covered by tests


 
## How to Use
- Clone this repo to use it as a building block for your project
- You'll need a postgre database. You can 
- When cloned, create `.env` file and fill in following info to be able to run the app against a local database.
  - ```
    FIREBASE_PROJECT_ID=your-firebase-project-id
    IP_SECRET_API_KEY=your-indiepitcher-api-key
    ```
    - This is enough to run the project locally. When deploying to production, you'll want to add the database connection keys, as well as optionally your mixpanel and sentry credentials
    - You can copy the `FIREBASE_PROJECT_ID` from `.env.testing` to try things out, but please do create your own firebase project.
    - `IP_SECRET_API_KEY` is for sending emails. You can create one for free by visiting https://indiepitcher.com or by replacing injecting `IndiePitcherEmailService` with `MockEmailService` to disable sending emails.
### Using PostgreSQL
- If you'd prefer using PostgreSQL (which your should for production), uncomment relevant lines in the template.
- You can use the `Dockerfile` to start up a database locally with following comands.
  - `docker-compose build`
  - `docker-compose up db` starts a local database to develop against
  - `docker-compose up db-test` starts a local database to run init tests against (this is a separate database so you don't wipe your data when running unit tests)
  - `docker-compose down` to shut the databases down, or just kill the docker app
- Running the project locally and running the unit tests should now work



## Deployment
You can deploy your backend anywhere that supports Docker. An obvious choice for many people would be AWS, I'm personally a fan of [Digital Ocean's App Platform](https://m.do.co/c/9e21fc78af92). 

I'd also encourage you to join the [vapor discord](https://discord.gg/vapor). Feel free to DM me there.

