import argparse
import requests
import json
import socket
import re
from datetime import datetime
from requests_ntlm import HttpNtlmAuth

def ValidateResults(rules, result, server):
	print "-" * 50
	
	for rule in rules:
		check = re.search(rule["rule"],result)
		
		if rule["validation"] == "present" and check is None:
			print "\tRule Validation Failure on server - %r. \"%r\" was not found in the returned results . . ." % (server, rule["rule"])
		elif rule["validation"] == "absent" and check is not None:
			print "\tRule Validation Failure on server - %r. \"%r\" was found in returned results . . . " % (server, rule["rule"])
		else:
			print "\tValidation Passed on server - %r. Rule - %r . . ." % (server, rule["rule"])
	
		print ""
	
def GetWebRequest(url,server, authentication):
	
	print "[%r] - Requesting %r on server %r" % (str(datetime.now()), url, server)
	
	timeout = 10
	socket.setdefaulttimeout(timeout)
	proxy = { "http" : "http://{0}".format(server) }

	r = requests.get(url, proxies=proxy, auth=authentication)
	#print "Received status code - %r - with text results -\n %r" % (r.status_code, r.text)
	
	if r.status_code == 200:
		return r.text
	else:
		return ""
		

parser = argparse.ArgumentParser(description="Validate a Website Against a list of Rules")
parser.add_argument('--username', metavar='U', help='A username for the web site to process')
parser.add_argument('--password', metavar='P', help='The password for username')
parser.add_argument('--config', metavar='C', help='Path to a json config file')
args = parser.parse_args()

with open(args.config) as data_file:
	data = json.load(data_file)

auth =  HttpNtlmAuth(args.username,args.password) if args.username is not None else None

for validation in data["validations"]:
	for server in validation["servers"]:
			result = GetWebRequest(validation["url"],server["server"], auth)
			ValidateResults(validation["rules"], result, server["server"])
