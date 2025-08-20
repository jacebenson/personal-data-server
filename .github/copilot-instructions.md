# Product Description
This project is a Ruby on Rails 7 application designed to manage all sorts of data.  
All data is stored in sqlite3.  
All user data is private and not shared with any third parties.

## Project Structure

- `app/assets/*`: Contains static assets like stylesheets, JavaScript files, and images.
- `app/controllers/*.rb`: Contains the controllers that handle requests and responses.
- `app/javascript/application.js`: The main JavaScript file for the application used to initialize JavaScript libraries and custom scripts from importmap.
- `app/jobs/*.rb`: Contains background jobs for processing tasks asynchronously.  We use this to process any long-running tasks like importing data and recurring lookups.
- `app/models/*.rb`: Contains the models that represent the data and business logic.
- `app/views/*`: Contains the html templates for rendering views.
- `app/views/layouts/application.html.erb`: The main layout file that wraps around all views.
- `app/views/shared/*.html.erb`: Contains shared partials used across multiple views.
- `app/views/personal/*.html.erb`: Contains views specific to the personal section of the application.
- `app/views/shopping/*.html.erb`: Contains views related to shopping data management.
- `app/views/financial/*.html.erb`: Contains views related to financial data management.
- `app/views/health/*.html.erb`: Contains views related to health data management.
- `app/views/dashboard/*.html.erb`: Contains views for the dashboard and overview pages.

## Project guidelines
- Use Ruby on Rails conventions for naming and structuring files.
- Follow RESTful principles for controllers and routes.
- Use partials for reusable view components.
- Keep controllers thin and move business logic to models or service objects.
- Use background jobs for long-running tasks to keep the application responsive.
- Use Tailwind CSS for styling and layout.
- Avoid Javascript if possible, instead use pages to achieve the affect Unless asked for specifically.
- Use Turbo for enhancing user experience with minimal JavaScript.
- Use Partials to simplify views and avoid duplication, these can exist in the `app/views/foldername/` unless shared, then use `app/views/shared/` directories.
- We are not using kaminari for pagination, instead we use a simple pagination method that works with the current data set.
- Do not use `rails console` for testing or debugging, instead use sqlite3 or create a test file in `test/` directory.
- Do not try to start the server as it is generally running.  If you need to restart the server touch the file `tmp/restart.txt` to restart the server.
- When testing you cannot open webpages as moste routes are protected by authentication.  Instead use the `rails test` command to run tests in the `test/` directory.
- When writing queries use things the SQLITE3 supports.
