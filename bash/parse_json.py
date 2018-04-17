#!/usr/bin/python3

import sys, getopt
import json

def main():
    helpmessage='getinfo.py -i <json> -o <AccessKeyId,SecretAccessKey,SessionToken>'
    try:
        opts, args = getopt.getopt(sys.argv[1:],"hi:o:",["istring=","ostring="])
    except getopt.GetoptError as err:
        print("err\nhelpmessage", err,helpmessage)
        sys.exit(2)

    inputfile = ''
    outputinfo = ''
    for o, a in opts:
        if o == '-h':
            print(helpmessage)
        elif o == '-i':
            inputfile = a
        elif o == '-o':
            if a in ("AccessKeyId","SecretAccessKey","SessionToken"):
                outputinfo = a
            else:
                print(helpmessage)
    with open(inputfile) as jsonfile:
        data = json.load(jsonfile)['Credentials']
        print(data[outputinfo])

if __name__ == "__main__":
       main()
