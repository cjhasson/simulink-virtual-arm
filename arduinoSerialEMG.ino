
void setup() {
  Serial.begin(19200,SERIAL_8N1);
}

void loop() {
  int sensorValue1;
  int sensorValue2;
  char buffer[9];

  sensorValue1 = analogRead(A0);
  sensorValue2 = analogRead(A1);
  
  sprintf(buffer, "A%03.3dB%03.3dX", sensorValue1, sensorValue2);
  Serial.print(buffer);
  delayMicroseconds(10);
}
