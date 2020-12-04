#!/usr/bin/env groovy
import hudson.model.*
import hudson.EnvVars

// a convestion of RTC build defition to a jenkinsfile
// all variables to be treated as case sensitive

// define what is needed for the build
// add the default environment where UcD will deploy

/***************** SonarQube ********************/
sonarhome = '/application/sonar-scan'
sonarhosturl = 'https://sonarqube-dtna.app.corpintra.net'
runsonarscannner = 'false'									//if 'true' then scan everytime - else only for release 

/******************* UCD ************************/
ucdenvironment = 'dev'
ucdapplicationprocess = 'deploy specific version'
ucdurl = 'https://uc-dtna.app.corpintra.net'

def initvars () {

	string truncatedgiturl  =  "${env.GIT_URL}".replace(".git","")
	tokens = truncatedgiturl.tokenize('/')
	prefix = tokens[0]
	giturl = tokens[1]
	gitapiurl = "https://${giturl}/api/v3"
	gitorg = tokens[2]
	gitrepo = tokens[3]
	application = tokens[2]				// replace tokens[2] with the name of the application, if different from git orginization
	component = tokens[3]				// replace tokens[3] with the name of the component, if different from git repository
	sonarprojectkey = "${gitrepo}"
	committeremail = getcommitteremail()
	taggerlogin = ''

}


/***********************************************************************************************************************************************************************************************************/

pipeline {

	agent {
		node {
			// listing the labels corresponding with the jenkins nodes
			label 'docker'
		}
	}
			
	options { 
		timestamps () 
		buildDiscarder(logRotator(numToKeepStr: '30', daysToKeepStr:'30', artifactNumToKeepStr: '10', artifactDaysToKeepStr: '5'))  //keep 30 logs up to 30 days -  10 artifacts up to 5 days
	}
   
   environment {
		//adding environment variables
		DOCKER_HUB = 'docker-registry-dtna.app.corpintra.net'
	}
	
    stages {
		stage('init') {
			steps {
				initvars()					// init global variables
				createautomation()			// create automation directory in workspace -- required by UrbanCode on deploy
			}
		}
	    stage('building') {
		   	// sometimes building inside a container fails, re-try again
			steps {
			retry(2) {		
					create()			 // create container and push to dtna docker registry
				}
		    }
		}
		stage('scanning') {
			when { 			//run when a tag/release is created by a person or runsonarscanner == 'true'	
				anyOf{
					tag '*'									
					expression { "${runsonarscannner}" == 'true' }
				}
			} 	    
			steps {		
				script {
					sonarscan()			
				}
			}
		}		
	}
	post {
		always {
            echo 'Post'
            deleteDir() /* clean up our workspace */
        }
		failure	{   //notify developers of failed build		
			script{
				def emailto = ''
				if("${committeremail}" != null && !"${committeremail}".trim().isEmpty()) {
					emailto = "${committeremail}"	
				}					
				else {
					echo "committeremail is null"
					emailto = "randy.burns@daimler.com"
				}
			
				emailext body: "${env.Build_URL} buildResult = ${currentBuild.result}",
						 recipientProviders:[ [$class: 'DevelopersRecipientProvider'] ],
						 subject: "Status of pipeline: ${currentBuild.fullDisplayName}  buildResult = ${currentBuild.result}",
						 to: "${emailto}"	
			}					 
		}
	}	
}

/***********************************************************************************************************************************************************************************************************/

def create () {

	withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'DTNA_CVD_s_JENKINS01',
                    usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']])
		{
		
			// build the container
			// login to the docker harbor
			// tag the image
			// push the image to the harbor
			// remove all images from the build box
			// logout from the hub
				
			sh "docker build -f dockerfile -t ${component}:${env.BRANCH_NAME} ."
			sh "docker login -u ${env.USERNAME} -p ${env.PASSWORD} ${env.DOCKER_HUB}"
			sh "docker tag ${component}:${env.BRANCH_NAME} ${env.DOCKER_HUB}/library/${component}:${env.BRANCH_NAME}"
			sh "docker push ${env.DOCKER_HUB}/library/${component}:${env.BRANCH_NAME}"
			sh 'docker rmi -f $(docker images -a -q) || exit 0' //allow to move forward even if removing images command fails
			sh "docker logout ${env.DOCKER_HUB}"			
			
		}			
}

def ucdeploy() {
	
	withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'DTNA_CVD_s_JENKINS01',
                    usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']])
		{
			// create a version of the component
			// add the jenkins job link to the component
			// populate the component with everything under /automation
			// link the creator to the version, hard-coded as jenkins pending research
			// create a json deployment string
			// kick off UcD deployment
			
			sh "java -jar udclient.jar --verbose --username ${env.USERNAME} --password ${env.PASSWORD} --weburl ${ucdurl} createVersion --component \"${component}\" --name \"${env.BRANCH_NAME}\""
			sh "java -jar udclient.jar --verbose --username ${env.USERNAME} --password ${env.PASSWORD} --weburl ${ucdurl} addVersionLink  --component \"${component}\" --version \"${env.BRANCH_NAME}\" --linkName pipeline --link ${env.JOB_DISPLAY_URL}"
			sh "java -jar udclient.jar --verbose --username ${env.USERNAME} --password ${env.PASSWORD} --weburl ${ucdurl} setComponentVersionPropDef --component \"${component}\" --version \"${env.BRANCH_NAME}\" --name \"buildRequester\" --value ${env.USERNAME}"
			sh "java -jar udclient.jar --verbose --username ${env.USERNAME} --password ${env.PASSWORD} --weburl ${ucdurl} addVersionFiles --component \"${component}\" --version \"${env.BRANCH_NAME}\" --base ./automation || exit 0" //do not allow this to fail

			envlist = ["${ucdenvironment}","DEV","test","dev"]   //list of possible dev environment names
			noenverror='The value given for'		//target error message 
			for (int i = 0; i < envlist.size(); i++) {
				try	{
					ucdenvironment = envlist[i]				
					sh "echo {  \"application\": \"${application}\",\"applicationProcess\": \"${ucdapplicationprocess}\",\"environment\": \"${envlist[i]}\",\"versions\": [{\"component\": \"${component}\",\"version\": \"${env.BRANCH_NAME}\"}]} > ${application}.json"
					sh "java -jar udclient.jar --verbose --username ${env.USERNAME} --password ${env.PASSWORD} --weburl ${ucdurl} requestApplicationProcess ${application}.json"
					break
				}
				catch(err)	{				
					echo err.toString()
				}
				continue
			}		
		}
}


/******************************************************************** utility methods ****************************************************************************************/

def sonarscan () {

	// scanning code to sonarqube
	
	withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'dtna_cvd_s_jenkins01_scan_token',
                    usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']])	{
		try	{
			if(isUnix())	{
				sh "${sonarhome}/bin/sonar-scanner -Dsonar.projectKey=\"${sonarprojectkey}\" -Dsonar.projectVersion=\"${env.BRANCH_NAME}\" -Dsonar.java.libraries=. -Dsonar.java.binaries=. -Dsonar.projectBaseDir=\"${env.WORKSPACE}\" -Dsonar.host.url=\"${sonarhosturl}\" -Dsonar.login=${env.PASSWORD}"	
			}
			else {
				bat "${sonarhomewin}/bin/sonar-scanner -Dsonar.projectKey=\"${sonarprojectkey}\" -Dsonar.projectVersion=\"${env.BRANCH_NAME}\" -Dsonar.java.libraries=. -Dsonar.java.binaries=. -Dsonar.projectBaseDir=\"${env.WORKSPACE}\" -Dsonar.host.url=\"${sonarhosturl}\" -Dsonar.login=${env.PASSWORD}"	
			}
		}
		catch(err)	{				
			echo 'Error in analysis/sonar-scanner stage:' + err.toString()		
			unstable('analysis stage failed!')  //sets current stage and build to "Unstable"  
			
			emailext body: "${env.Build_URL} buildResult = ${currentBuild.result}",
				 recipientProviders: [requestor()],
				 subject:  "Status of pipeline: ${currentBuild.fullDisplayName}  analysis stage Failed! buildResult set to ${currentBuild.result}",
				 to: "${committeremail}"					
		}							
	}
}

def createautomation() {
	try	{
		if(isUnix()){
			sh 'mkdir automation || exit 0'
		}
		else {		
			bat "mkdir automation"		
		}
	}
	catch(err)	{
		//do not show error
	}
}

def clearautomation() {
	try	{
		if(isUnix()){
			sh 'rm ./automation/*.*'
		}
		else {		
			bat "del /Q .\\automation\\*.*"
		}
	}
	catch(err)	{  
		echo "Error in clearautomation: " + err.toString()
	}
}

def getcommitteremail() {	
	try {
		def committer = ''
		if(isUnix()) {	
			committer = sh(returnStdout: true, script: "git --no-pager show -s --format=\"%ae\" ${env.GIT_COMMIT}").trim()		
		}
		else {
			committer = bat(returnStdout: true, script: "@git --no-pager show -s --format=\"%%ae\" ${env.GIT_COMMIT}").trim()
		}
		echo "git last commit author email (committeremail): ${committer}"
		
		return committer	
	}
	catch(err)	{
		echo "Error in getcommitteremail: " + err.toString()
	}	
}

def getreleasenotes() {
	if(isUnix())	{
		try	{
			def currenttag = sh(returnStdout: true, script: "git describe --abbrev=0 --tags ${env.GIT_COMMIT}").trim()
			def previouscommit = sh(returnStdout: true, script: "git rev-list --tags --max-count=1 --skip=1").trim()
			def previoustag = sh(returnStdout: true, script: "git describe --abbrev=0 --tags ${previouscommit}").trim()
			def releasenotes = sh(returnStdout: true, script: "git log ${previoustag}..${currenttag} --pretty=format:\"%h - %an, %ar : %s%x0D%x0A\"")	
			writeFile file: "automation/releasenotes.txt", text: "${currenttag}-${releasenotes}"
		}
		catch(err)	{
			echo "Error in getreleasenotes: " + err.toString()
		}	
	}
	else {	 // os is windows
		try	{
			def currenttag = bat(returnStdout: true, script: "@git describe --abbrev=0 --tags ${env.GIT_COMMIT}").trim()
			def previouscommit = bat(returnStdout: true, script: "@git rev-list --tags --max-count=1 --skip=1").trim()
			def previoustag = bat(returnStdout: true, script: "@git describe --abbrev=0 --tags ${previouscommit}").trim()
			def releasenotes = bat(returnStdout: true, script: "@git log ${previoustag}..${currenttag} --pretty=format:\"%%h - %%an, %%ar : %%s%%x0D%%x0A\"")	
			writeFile file: "automation/releasenotes.txt", text: "${currenttag}-${releasenotes}"
		}
		catch(err)	{
			echo "Error in getreleasenotes: " + err.toString()
		}
	}	
}

def gettaggerlogin(tag) {
	try {
		withCredentials([string(credentialsId: 'dtna_cvd_s_jenkins01_github_token', variable: 'GH_TOKEN')])	{
			def apiurl = "${gitapiurl}/repos/${gitorg}/${gitrepo}/releases/tags/${tag}" 
			def tagger = ''
			
			if(isUnix()) {
				tagger = sh(returnStdout: true, script: "curl -s -H \"Authorization: Token $GH_TOKEN\" -H \"Accept: application/json\" -H \"Content-type: application/json\" -X GET ${apiurl} | jq '.author.login'").trim()
			}
			else {
					tagger = bat(returnStdout: true, script: "@\"c:/cygwin64/bin/curl\" -s -H \"Authorization: Token $GH_TOKEN\" -H \"Accept: application/json\" -H \"Content-type: application/json\" -X GET ${apiurl} | \"c:/cygwin64/bin/jq\" '.author.login'").trim()
			}
			return tagger
		}
	}
	catch(err)	{
		echo "Error in gettaggerlogin(tag): " + err.toString()
	}
}
