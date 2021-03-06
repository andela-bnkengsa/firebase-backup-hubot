# Description:
#   Performs the data export/upload operations.

async = require('async')
AWS = require('aws-sdk')
admin = require('firebase-admin')
moment = require('moment')
filesize = require('filesize')
env = require('dotenv')
env.config({silent: true})

serviceAccount = require(process.env.PATH_TO_SERVICE_ACCOUNT_KEY)
admin.initializeApp
  credential: admin.credential.cert(serviceAccount)
  databaseURL: process.env.FIREBASE_DB_URL
  databaseAuthVariableOverride: uid: 'firebase-backup-bot'

auth = (cb) ->
  db = admin.database()
  ref = db.ref('/')
  cb null, ref

dataExport = (rootRef, cb) ->
  rootRef.once 'value', ((snap) ->
    data = snap.exportVal()
    cb null, data
  ), (error) ->
    cb error, null

dataSize = (rootRef, cb) ->
  rootRef.once 'value', (snap) ->
    data = JSON.stringify(snap.val());
    bytes = Buffer.byteLength(data, 'utf8')
    cb null, filesize(bytes)

dataUpload = (data, cb) ->
  date = new Date
  dateStr = moment(date).format('YYYY-MM-DDTHH:MM:SSZ')

  key = "#{dateStr}_#{process.env.FIREBASE_DB_NAME}_data.json"
  payload = JSON.stringify(data)

  AWS.config.region = process.env.AWS_REGION

  s3 = new (AWS.S3)
  s3.createBucket { Bucket: process.env.AWS_BUCKET_NAME }, ->
    params =
      Bucket: process.env.AWS_BUCKET_NAME
      Key: key
      Body: payload
    s3.upload params, (err, data) ->
      bytes = Buffer.byteLength(payload, 'utf8')
      cb err, filesize(bytes)

format = (err, result) ->
  msg = null

  if err
    msg = "Something went wrong: #{err.message}"
  else
    msg = "#{result}"

  return msg

module.exports = (robot) ->
  robot.on 'backup', (res) ->
    async.waterfall [
      auth
      dataExport
      dataUpload
    ], (err, result) ->
      robot.emit 'done', {
        res: res,
        msg: format(err, result)
      }

  robot.on 'size', (res) ->
    async.waterfall [
      auth
      dataSize
    ], (err, result) ->
      robot.emit 'done', {
        res: res,
        msg: format(err, result)
      }