#!/bin/bash
false & &>log1 echo one;wait;echo two; &>log2 echo three;echo four; &>log3 echo five;cat log1 log2 log3;