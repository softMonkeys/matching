#coding: utf-8
#!/usr/bin/python
#file name           : matcher.py
#author              : Garrett Nicolai
#email               : nicolai@ualberta.ca
#date                : 2016-08-15
#python_version      : 2.7.6

#This code is a wrapper for the ranking software constructed by the 
#group at the University of Alberta during the summer of 2016.  
#It consists of two phases: feature extraction, and score prediction
#The first step transforms the resume into a feature vector that marks
#the resume for various features such as keyword n-grams, time durations,
#employment history, and other features.
#At test time, this feature file is evaluated by a support vector machine
#against a previously learned model, and a score is produced that predicts
#the likelihood that this applicant should be hired or not.
#This is the only part of the code that should be accessed from the front end:
#When a new application is posted, it should be scored by the SVM, and this
#score should be saved. 
#When the client then chooses to rank the applications, 
#they can be ranked according to score.
#In order to make this feature compatible with older job posts, it the 
#resume has no score, it should be scored.

#For training, any of the dependencies should be able to be re-constructed
#at any time.  These include: the SVM-model and the keyword files.  
#However, this feature should not be available on the website, and should
#only be performed periodically on the backend, as more training data becomes
#available.

import os, json, sys, ast
import subprocess
import shutil

curr_dir  = os.path.abspath(os.path.join(os.path.dirname(__file__),"."))
home_dir  = os.path.abspath(os.path.join(os.path.dirname(__file__),".."))
error_dir = home_dir + '/error/'

sys.path.append(error_dir)
from errorcode import *
sys.path.append(home_dir)
sys.path.append(curr_dir)


class Matcher():

      def __init__(self):
          self.success = 'success'
          self.error   = 'error'
          self.error_code = 'Errorcode()'
          print 'Linguax Auto-matcher loaded...'

      def test(self, resume, response, jobDesc):
	# initialize JSON objects that are gonna be used for the matching
	  ToParseJSON = {}
	  experiences = []
	  educations = []

	# get the Resume as a JSON file
          ToParseJSON['resume'] = json.loads(str(resume[1]))
	  print ToParseJSON
	  hrJson = ToParseJSON['resume']['hrJson']
	  hgJson = ToParseJSON['resume']['hgJson']
	  secText = ToParseJSON['resume']['hgJson']['SectionText']

	# get all sections in hgJson
	  objective = hgJson.get('Objective', "empty")
	  summary = hgJson.get('Summary', "empty")
	  skill = secText.get('Skill', "empty")
	  sec_exp = secText.get('Experience', "empty")
	  sec_educ = secText.get('Education', "empty")
	  sec_contact = secText.get('ContactInfo', "empty")

	# get all sections in hrJson
	  experience = hrJson.get('PositionHistory', "empty")
	  rawText = ToParseJSON['resume'].get('rawText', "empty")
	  education = hrJson.get('EducationOrganizationAttendance', "empty")

	# only fill experience and education arrays when they are not empty
	  if experience is not "empty":
		for exp in experience:
			experiences = self.experienceJSON(exp, experiences)
	  if education is not "empty":
		for educ in education:
			educations = self.educationJSON(educ, educations)

	# construct JSON to test with SVM
	  self.constructJSON(rawText, experiences, educations, skill, summary, objective, sec_contact, sec_educ, sec_exp, jobDesc)
	
      def constructJSON(self, rawText, experiences, educations, skill, summary, objective, sec_contact, sec_educ, sec_exp, jobDesc): 
	  PrintJSON = {}
	  FinalJSON = {}

	  applications = []
	  PrintJSON['resume'] = {}
	  PrintJSON['resume']['rawText'] = rawText
	  PrintJSON['resume']['resumeSections'] = {}	
	  
	  PrintJSON['stage'] = 'New'
	  PrintJSON['resume']['experience'] = experiences	  
	  PrintJSON['resume']['education'] = educations
	  PrintJSON['resume']['resumeSections']['Skill'] = skill
	  PrintJSON['resume']['summary'] = summary
	  PrintJSON['resume']['objective'] = objective
	  PrintJSON['resume']['resumeSections']['ContactInfo'] = sec_contact
	  PrintJSON['resume']['resumeSections']['Education'] = sec_educ
	  PrintJSON['resume']['resumeSections']['Experience'] = sec_exp
	  applications.append(PrintJSON)  

	# DEBUG: store results into a txt file
	  FinalJSON['applications'] = applications
	  FinalJSON['job'] = jobDesc
	  f = open("/home/linguaX-server/o.txt", "w")
	  f.write(json.dumps(FinalJSON, indent = 4))

      def constructDate(self):
	  DATE = {}
	  DATE['to'] = {}
	  DATE['from'] = {}
	  DATE['to']['date'] = "01-01-01"
	  DATE['from']['date'] = "01-01-01"
	
	  return DATE
	
      def educationJSON(self, educ, educations):
          educationJSON = {}
          educ = ast.literal_eval(str(educ))
          date = educ.get('AttendanceStartDate', "empty")
          educationJSON['school'] = educ.get('School', "empty")
          educationJSON['order'] = '-Infinity'
          educationJSON['major'] = educ.get('MajorProgramName', "empty")[0]
          deg = educ.get('DegreeType', "empty")[0]
	  if type(deg) == type(dict()):
		  educationJSON['degree'] = deg.get('Name', "empty")
          educationJSON['level'] = educ.get('EducationLevel', "empty")
          educations.append(educationJSON)

          return educations

      def experienceJSON(self, exp, experiences):
          experienceJSON = {}
          exp = ast.literal_eval(str(exp))
          date = exp.get('StartDate', "empty")
          experienceJSON['date'] = self.constructDate()
	  experienceJSON['position'] = exp.get('PositionTitle', "empty")
          experienceJSON['description'] = exp.get('Description', "empty")
          experienceJSON['company'] = exp.get('Employer', "empty")
          experienceJSON['order'] = '-Infinity'
	  self.constructDate()
          experiences.append(experienceJSON)

          return experiences

 #     def get_score(self):
#	  tmp_dir = '/home/linguaX-server/linguaX-Django/apps/matcher/o.txt'	# file with feature vector that represents new applicant
#	  perl_cmd = ['perl get_feature_vectors_v14b.pl', '-s', '0', '-d', tmp_dir, '-fw FunctionWords.txt -c 1 -t 1 -o 1 -k 1 -i 1 -l 1 -b 1 -ec 1 -eo 1 -time 0 -if 0 --keyword-file keywords-freq.txt --keyword-limit 2500 --keyword-intersection-file intersectionKeywords-freq.txt --local-keyword-limit 2500 --keybigram-file bigrams-freq.txt --keybigram-limit 2500']
	  
#      def sendScore(score):
	  # send to StartDate
	  # httpResponse? or send back to LinguaX parser

'''      def get_scores(self, resume, fw_file, count_on, threshold_on, overlap_on, keyword_on, intersection_on, local_on, bigram_on, edu_cumul_on, edu_1h_on, time_on, ill_formed_on, keyword_file, keyword_limit, keyword_inter_file, keyword_inter_limit, local_limit, keyword_bigram_file, bigram_limit, svm_file, prediction_file):

          temp_dir  = os.path.abspath(os.path.join(curr_dir,"new_dir"))
	  print temp_dir
          if not os.path.exists(temp_dir):
             os.makedirs(temp_dir)
          resume_path = os.path.abspath(os.path.join(temp_dir, resume))
          shutil.copy2(resume, resume_path)


          cmd = ['perl', './get_feature_vectors_v14b.pl', '-s', '0', '-d', temp_dir, '-fw', fw_file, '-c', count_on, '-o', overlap_on, '-k', keyword_on, '-i', intersection_on, '-l', local_on, '-b', bigram_on, '-ec', edu_cumul_on, '-eo', edu_1h_on, '-time', time_on, '-if', ill_formed_on, '--keyword-file', keyword_file, '--keyword-limit', keyword_limit, '--keyword-intersection-file', keyword_inter_file, '--local-keyword-limit', local_limit, '--keybigram-file', keyword_bigram_file, '--keybigram-limit', bigram_limit]

          proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)

          feature_file = 'temp_feature_file'
          save2file(proc.stdout, feature_file)
          svm_model = svm_file
          output = prediction_file
          cmd = ['./svm_classify', feature_file, svm_model, output]
          subprocess.call(cmd)
          shutil.rmtree(temp_dir)
'''

def demo():
   
    matchTest = Matcher()
    matchTest.get_scores('testfile.txt', 'FunctionWords.txt', '1', '1', '1', '1', '1', '1', '1', '1', '1', '1', '1', 'keywords.txt', '5000', 'intersectionKeywords.txt', '5000', '5000', 'bigramKeywords.txt', '5000', 'SVMModel', 'SVM_Predictions.txt')

def save2file(out, filename):
    f = open(filename, 'w')
    for line in out:
        f.write(line)
    f.close()
    return


if __name__ == '__main__':
    demo()


