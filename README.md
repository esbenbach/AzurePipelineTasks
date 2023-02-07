# AzurePipelineTasks
Various Azure DevOps Pipeline tasks.

Currently contains a simple Task for Downloading specific artifacts in a stage.
Useful when you have release with multiple artifacts where paralell stages are run that requires an artifact each (the built in downloader does not support this scenario).

# Credits

The Download Artifacts task started life as a fork from https://github.com/chamindac/vsts.release.task.download-artifacts however it was getting old and was not maintained, so I decided to revisit it.