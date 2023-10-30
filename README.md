# SAAS Backend Starter Template
This is an extension of Vapor's [starter template](https://github.com/vapor/template) to get the backend for your next SAAS off the ground. Or if you're jsut curious about server-side Swift and Vapor, and would like to see some real code.

It takes care of the tedious tasks for you, user management, sending emails, analytics, error logging...

Every SAAS needs to handle user sign up, and if your service takes off, you'll start being asked by customers how they can invite their colleagues. This ends up being a huge pain if everything is tied to a user profile instead of an organization unit. That's why this template includes a complete organization management with 3 levels of user permission. You can create a default org with a user profile during sign up that's hidden from the user, that's fine, and you are ready for to future.

//TODO: list of endpoints

- This repo will be expanded and kept up to date with the latest Swift and Vapor releases, feel free to subscribe for updates and check out the (roadmap)[https://github.com/users/petrpavlik/projects/3/views/1]
- **I'm working on a course explaining everything in in a very detailed way. Scroll down to learn more.**

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
  - Can be swapped for Sendgrid or other solution
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
- When cloned, create `.env` file and fill in following info
  - ....
- To be able to run the unit tests, create `.env.testing` file and fill in following info
- Set up your local dev environment by downloading Docker and typing in following commands
  - `docker-compose build`
  - `docker-compose up db` starts a local database to develop against
  - `docker-compose up db-test` starts a local database to run init tests against (this is a separate database so you don't wipe your data when running unit tests)
  - `docker-compose down` to shut the databases down, or just kill the docker app
- Running the project locally and running the unit tests should now work



## Deployment
You can deploy your backend anywhere that supports Docker. An obvious choice for many people would be AWS, I'm personally a fan of [Digital Ocean's App Platform](https://m.do.co/c/9e21fc78af92). 
You can also check out fly.io since they offer a free tier, or good old Heroku using the swift buildpack.



## Want to Learn More?
I'm hard at work working on a video course providing a detailed walk through of this template and Vapor framework in general. If you're interested, or would just like to support further development, you can [pre-order the course at a 50% discount](https://buy.stripe.com/4gwbLy5X02MqaModQQ). You'll get all the materials to the amail you provide during the checkout as soon as I start rolling the course out.

