# Todo

I want the following todo points to be created as github issues. Each issue to be split according to each point in the todo list. The description of each point don't have to be copied exactly, a more elaborate description can be generated.
For example an proposed implementation plan, or available options how the issue can be solved. The issue description should leave room for imagination, not tunnelvision.

## Todo points

- Specify location where the buffer file is stored
- Perhaps change the setup of the test suite to be more lightweight and split up.
- Add a src folder for the production logic
- Deinstallation steps or script
- Make it like an upsert to an existing Oh My Posh configuration, we don't want to mess up someone's configuration. It must be seen as an extra.
- Windows location services using powershell? How reliable is the current ip lookup?
- No Fallback location, I rather see 'not available' or an icon representing this in the CLI
- I want to check if we can get some indication of traffic using the API's. Not based on minutes as a long journey can still be 'traffic free' but a lot of kilometers.
- if the journey takes less than a hour, I don't want the hours to be displayed. '59 m' instead of '0h 59m'
- How would the logging work for a scheduled task? Is it common to show anything in the CLI? Or should we log it to the Event Viewer or something?
- Why are we storing journey distance in the buffer file? We don't need it to make a discicion?
- We need to create a Github respository, issues for the above findings, and a pipeline to test the scripts when a push is made to the main branch
- Is there a free route calculator including traffic? Perhaps we should offer to switch between the two during installation
- The home address can have some basic checks as well, but not too complicated
- Why the empty catch on Install-TravelTimeService.ps1 line 210?
- In the scripts I see some assumptions that the repository cloned locally will be the working directory of the scripts. I don't want that.
The repository is cloned for development purposes. I eventually want a release package on Github that can be downloaded by the end users.
Updating the GitIgnore for example in the Install-TravelTimeService.ps1 line 226 won't be used by the end user.
- I want the TravelTimeUpdater.ps1 to log more in debug statements. Reserve information level for actual important logging for each cycle.
- ✅ What license would best fit this project, I want to encourage contributers to contribute. I would like this logic to be used within commercial projects and for individuals. **COMPLETED: MIT License added**
- I want all the commonly used open source repository files, like CONTRIBUTING etc.. present on the root level of this repository. Describe a plan how to do this.
- I want to not only support powershell OhMyPosh, the other common terminals as well.
- I want to support different OS systems as well, so a Powershell Scheduled task to create the buffer file won't work as is, the script has to probably be rewritten separately
- I want to package the logic in a seperate distributable with release versioning, so at least a versioning logic has to be implemented with a pipeline. I want Semantic versioning.
- I want a pipeline to package the latest version during the main build in a separate distributable, a installation manual and overview of current features in markdown should be packaged with the software.
- I haven't been using Github lately, there are perhaps features that aren't mentioned yet in other points which fit this kind of project perfectly, either in the pipelines, documentation, distributing etc... Make a plan of the options.
- We have large ps1 files at the moment, there are probably functions present that can be put together in separate files that are later imported, to eventually understand what the actual business logic is, and what supporting infrastructure logic is for example.
