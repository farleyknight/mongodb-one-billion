# MongoDB - 1 Billion Key/Values

I want to test out the assumptions about what it takes to host 1 billion key/values pairs in a database engine. 

It is often said that relational DBs cannot handle the same scale as no-SQL DBs such as Mongo. I'm going to test this by doing the following:

1. Create a local version of a MongoDB container
   This is the container I will be using: https://hub.docker.com/_/mongo
2. Verify I can connect to it
   The main thing here is verifying that I can connect via Python to a MongoDB port
3. Deploy that container to AWS via Terraform
   A subgoal here is actually learning entough AWS-flavored-Terraform code to be able to do this.
   Here's a good tutorial on bringing up a container in general:
   https://klotzandrew.com/blog/deploy-an-ec2-to-run-docker-with-terraform
4. Write a Python script that loads the MongoDB instance with as many key/value pairs I can 
   generate.
   Make sure the keys are roughly "the length of a URL". They could be actual URLs, to be frank.
   The values will be integers, as they will only represent the frequency of the URL showing up 
   in the dataset.
5. At some point the MongoDB should start slowing down because of too much data.
   **This is the fun part :)**
6. See if we can partition the dataset "live" by creating a new MongoDB and putting half 
   the data on it.
   We may also need a coordinator MongoDB node to route traffic between the two nodes.
