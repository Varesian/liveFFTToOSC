import ddf.minim.analysis.*;
import ddf.minim.*;

Minim minim;
//AudioPlayer jingle;
AudioInput in;
FFT fft;
String windowName;
int numBands = 24;
int curNumBands;
int scaleFactor = 5;
float oscAmpThresh = 5;
float currBinVals[];
float currFrameMaxAvgVal = 0;

//for OSC
import oscP5.*;
import netP5.*;
OscP5 oscP5;
NetAddress myRemoteLocation;

void setup()
{
  size(512, 400);
  minim = new Minim(this);
  in = minim.getLineIn(Minim.STEREO, 2048);
  
  curNumBands = numBands;
  currBinVals = new float[numBands];
  
  //jingle = minim.loadFile("drum_solo.mp3", 2048);
  //jingle.loop();
  // create an FFT object that has a time-domain buffer the same size as jingle's sample buffer
  // note that this needs to be a power of two and that it means the size of the spectrum
  // will be 512. see the online tutorial for more info.
  fft = new FFT(in.bufferSize(), in.sampleRate());
  fft.linAverages(numBands);
  fft.window(FFT.HAMMING);

  textFont(createFont("SanSerif", 12));
  windowName = String.valueOf(numBands) + " bands";
  
  oscP5 = new OscP5(this, 12000);
  myRemoteLocation = new NetAddress("127.0.0.1", 57001);
}


void drawRaw() {
  stroke(0, 0, 255);
  for(int i = 0; i < fft.specSize(); i++)
  {
    // draw the line for frequency band i, scaling it by 4 so we can see it a bit better
    line(i, height / 2, i, height / 2 - fft.getBand(i)*4);
  }
}

void analyzeFrame() {
  
  // reset max value
  currFrameMaxAvgVal = 0;
  
  for (int i = 0; i < fft.avgSize(); i++) {
    
    // get current bin avg val
    float currAvg = fft.getAvg(i);    
    
    // set currBinAvg val in array
    currBinVals[i] = currAvg;
    
    // adjust local max val variable if necessary
    if (currAvg > currFrameMaxAvgVal) {
      currFrameMaxAvgVal = currAvg;
    }
    
  }
  
}


void drawAverages() {
  int w = int(width / fft.avgSize());
  
  stroke(255);
  
  float maxBinAvgVal = 0;
  
  for(int i = 0; i < fft.avgSize(); i++)
  {
    // get current bin avg val
    float currAvg = fft.getAvg(i);    
    
    // if currAvg is greater than threshold we fill with green otherwise, white
    if (currAvg > oscAmpThresh) {
      fill(0, 255, 0);
    } else {
      fill(255);
    }
    
    // draw a rectangle for each average, multiply the value by scaleFactor so we can see it better
    rect(i * w, height - currAvg * scaleFactor, w, currAvg * scaleFactor);    
  }
  
  // draw a red line to indicate our current threshold value
  stroke(255, 0, 0);
  line (0, height - oscAmpThresh * scaleFactor, width, height - oscAmpThresh * scaleFactor);
}

void draw()
{
  background(0);
    
  if (curNumBands != numBands) {
    numBands = curNumBands;
    currBinVals = new float[numBands];
    fft.linAverages(numBands);
    windowName = String.valueOf(numBands) + " bands";
  }
  
  fft.forward(in.left);

  drawRaw();
  drawAverages();
  
  // populate the currBinVals array and the currFrameMaxAvgVal variable
  analyzeFrame();
  
  // TODO: currently only sending a single message with the max value for each frame
  if (currFrameMaxAvgVal > oscAmpThresh) {
    sendOSCMessage(currFrameMaxAvgVal, currBinVals);        
  }

  // keep us informed about the window being used
  text(windowName + " (+/- changes bands, u/d changes amplitude thresh)", 5, 20);
}

void keyReleased()
{
  if ( key == 'w' ) 
  {
    // a Hamming window can be used to shape the sample buffer that is passed to the FFT
    // this can reduce the amount of noise in the spectrum
    windowName = "Hamming";
  }
  
  else if ( key == 'e' ) 
  {
    fft.window(FFT.NONE);
    windowName = "None";
  }
  
  else if (key == '+') {
    curNumBands++;
  }
  else if (key == '-') {
    curNumBands--;
  }

  else if (key == 'u') {
    oscAmpThresh++;
  }
  else if (key == 'd') {
    oscAmpThresh--;
  }
  
  
}

void stop()
{
  // always close Minim audio classes when you finish with them
  in.close();
  minim.stop();
  
  super.stop();
}

void sendOSCMessage(float val, float[] binVals) {
  OscMessage myMessage = new OscMessage("/acw");
  myMessage.add("cc");
  myMessage.add(15);

  myMessage.add(val);
  if (binVals != null) {
    myMessage.add(binVals);
  }


  /* send the message */
  oscP5.send(myMessage, myRemoteLocation); 
  println("sent message: " + myMessage);
}
