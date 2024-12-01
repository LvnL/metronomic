import AVFoundation

class Metronome {
  private var audioUnit: AudioUnit?
  private var dispatchQueue: UnsafeMutablePointer<DispatchQueue> = UnsafeMutablePointer<DispatchQueue>.allocate(capacity: 1)
  private let nextFrame: UnsafeMutablePointer<Int> = UnsafeMutablePointer.allocate(capacity: 1)
  private var subdivisions: [String: Subdivision] = [:]
  private let validFrameCount: UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
  private var volume: Float?

  init() {
    dispatchQueue.initialize(to: DispatchQueue(label: "com.lvnlx.tempus", attributes: .concurrent))
    
    var audioComponentDescription: AudioComponentDescription = AudioComponentDescription(
      componentType: kAudioUnitType_Output,
      componentSubType: kAudioUnitSubType_RemoteIO,
      componentManufacturer: kAudioUnitManufacturer_Apple,
      componentFlags: 0,
      componentFlagsMask: 0
    )
    
    let audioComponent: AudioComponent? = AudioComponentFindNext(nil, &audioComponentDescription)
    guard AudioComponentInstanceNew(audioComponent!, &audioUnit) == noErr else {
      print("Error creating new audio component instance")
      return
    }
    
    guard AudioUnitSetProperty(
      audioUnit!,
      kAudioUnitProperty_StreamFormat,
      kAudioUnitScope_Input,
      0,
      &audioStreamBasicDescription,
      UInt32(MemoryLayout.size(ofValue: audioStreamBasicDescription))
    ) == noErr else {
      print("Error setting stream format property")
      return
    }
    
    let auRenderCallback: AURenderCallback = { inRefCon, _, _, _, inNumberFrames, ioData in
      let inRefCon = inRefCon.assumingMemoryBound(to: RefCon.self).pointee
      let inNumberFrames = Int(inNumberFrames)
      let ioData = ioData!.pointee.mBuffers.mData!.assumingMemoryBound(to: Float.self)
      
      let dispatchQueue = inRefCon.dispatchQueue
      let validFrameCount = inRefCon.validFrameCount.pointee
      
      for index in 0..<inNumberFrames {
        ioData.advanced(by: index).pointee = 0
      }
      
      dispatchQueue.pointee.sync {
        for index in 0..<inNumberFrames {
          inRefCon.nextFrame.pointee = inRefCon.nextFrame.pointee % validFrameCount
        
          for clip in clips {
            if (clip.pointee.isActive && !clip.pointee.isPlaying && clip.pointee.startFrame == inRefCon.nextFrame.pointee) {
              clip.pointee.isPlaying = true
            }
          
            if (clip.pointee.isPlaying) {
              if (clip.pointee.nextFrame < clip.pointee.sample.pointee.length) {
                ioData.advanced(by: index).pointee += clip.pointee.sample.pointee.data.advanced(by: clip.pointee.nextFrame).pointee * clip.pointee.volume
                clip.pointee.nextFrame += 1
              } else {
                clip.pointee.isPlaying = false
                clip.pointee.nextFrame = 0
              }
            }
          }
        
          inRefCon.nextFrame.pointee += 1
        }
      }
      
      return noErr
    }
    
    nextFrame.pointee = 0
    let refCon = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<RefCon>.size, alignment: MemoryLayout<RefCon>.alignment)
    refCon.storeBytes(of: RefCon(dispatchQueue: dispatchQueue, nextFrame: nextFrame, validFrameCount: validFrameCount), as: RefCon.self)
    var auRenderCallbackStruct: AURenderCallbackStruct = AURenderCallbackStruct(
      inputProc: auRenderCallback,
      inputProcRefCon: refCon
    )
    
    guard AudioUnitSetProperty(
      audioUnit!,
      kAudioUnitProperty_SetRenderCallback,
      kAudioUnitScope_Global,
      0,
      &auRenderCallbackStruct,
      UInt32(MemoryLayout.size(ofValue: auRenderCallbackStruct))
    ) == noErr else {
      print("Error setting render callback property")
      return
    }
    
    guard AudioUnitInitialize(audioUnit!) == noErr else {
      print("Error initializing audio unit")
      return
    }
  }
  
  func addSubdivision(_ key: String, _ option: Int, _ volume: Float) {
    subdivisions[key] = Subdivision(option, volume)
    updateClips()
  }
  
  func removeSubdivision(_ key: String) {
    subdivisions.removeValue(forKey: key)
    updateClips()
  }
  
  func setBpm(_ bpm: UInt16) {
    let bps: Double = Double(bpm) / 60.0
    let beatDurationSeconds: Double = 1.0 / bps
    validFrameCount.pointee = Int(beatDurationSeconds * Double(sampleRate))
    
    updateClips()
  }
  
  func setSubdivisionOption(_ key: String, _ option: Int) {
    subdivisions[key]!.option = option
    updateClips()
  }
  
  func setSubdivisionVolume(_ key: String, _ volume: Float) {
    subdivisions[key]!.volume = volume
    updateClips()
  }
  
  func setVolume(_ volume: Float) {
    self.volume = volume
    updateClips()
  }
  
  func startPlayback() {
    guard AudioOutputUnitStart(audioUnit!) == noErr else {
      print("Error starting audio output unit")
      return
    }
  }
  
  func stopPlayback() {
    nextFrame.pointee = 0
    for clip in clips {
      clip.pointee.isPlaying = false
      clip.pointee.nextFrame = 0
    }
    
    guard AudioOutputUnitStop(audioUnit!) == noErr else {
      print("Error stopping audio output unit")
      return
    }
  }
  
  private func updateClips() {
    let subdivisionClipData: [(Int, Float)] = subdivisions.values
      .reduce(into: [Float:Float]()) { (accumulator, subdivision) in
        for location in subdivision.getLocations() {
          if (subdivision.volume >= accumulator[location] ?? 0) {
            accumulator[location] = subdivision.volume
          }
        }
      }
      .map { (location, volume) in
        let exactLocation: Double = Double(validFrameCount.pointee) * Double(location)
        return (Int((exactLocation / Double(sizeOfFloat)).rounded()) * Int(sizeOfFloat), volume)
      }
    
    let downbeatClip: UnsafeMutablePointer<Clip> = UnsafeMutablePointer<Clip>.allocate(capacity: 1)
    downbeatClip.initialize(to: Clip(sample: samples["downbeat"]!, startFrame: 0, volume: volume!))
    
    let subdivisionClips: [UnsafeMutablePointer<Clip>] = subdivisionClipData.map { (startFrame, volume) in
      let subdivisionClip: UnsafeMutablePointer<Clip> = UnsafeMutablePointer<Clip>.allocate(capacity: 1)
      subdivisionClip.initialize(to: Clip(sample: samples["subdivision"]!, startFrame: startFrame, volume: volume))
      return subdivisionClip
    }
    
    dispatchQueue.pointee.async(flags: .barrier) {
      clips = clips.filter { $0.pointee.isPlaying }
      for index in clips.indices { clips[index].pointee.isActive = false }
      
      clips.append(downbeatClip)
      clips.append(contentsOf: subdivisionClips)
    }
  }
}
