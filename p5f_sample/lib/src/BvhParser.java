package com.rhizomatiks.bvh;

import java.util.ArrayList;
import java.util.List;

import processing.core.PApplet;
import processing.core.PMatrix3D;
import processing.core.PVector;

public class BvhParser {

  private boolean _motionLoop;
  
  private int _currentFrame = 0;
  
  private List<BvhLine> _lines;
  
  private int _currentLine;
  private BvhBone _rootBone;
  private List<List<Float>> _frames;
  private int _nbFrames;
  private float _frameTime;
  
  private List<BvhBone> _bones;
  
  public BvhParser()
  {
    init();
  }

  /**
   * if set to True motion will loop at end
   */
  public Boolean getMotionLoop()
  {
    return _motionLoop;
  }
  
  /**
   * set Loop state
   * @param value
   */
  public void setMotionLoop(Boolean value)
  {
    _motionLoop = Boolean.TRUE.equals(value);
  }

  /**
   * set Loop state
   * @param value
   */
  public void setMotionLoop(boolean value)
  {
    _motionLoop = value;
  }

  /**
   * to string
   * @return
   */
  public String toStr()
  {
    return _rootBone.structureToString();
  }
  
  /**
   * get frame total
   * @return
   */
  public int getNbFrames()
  {
    return _nbFrames;
  }

  /**
   * get the currently selected frame
   */
  public int getCurrentFrame()
  {
    return _currentFrame;
  }

  /**
   * get the duration of one frame in seconds
   */
  public float getFrameTime()
  {
    return _frameTime;
  }

  /**
   * get bones list
   * @return
   */
  public List<BvhBone> getBones()
  {
    return _bones;
  }


  /**
   * call before parse BVH
   * 	create array instance
   * 	and setloopstatus true
   */
  public void init()
  {
    _currentFrame = 0;
    _lines = new ArrayList<BvhLine>();
    _frames = new ArrayList<List<Float>>();
    _bones = new ArrayList<BvhBone>();
    _nbFrames = 0;
    _frameTime = 0;
    _rootBone = null;
    _motionLoop = true;
  }
  
  /**
   * go to the frame at index
   */
  public void moveFrameTo(int __index)
  {
    ensureMotionData();

    if (_motionLoop) {
      _currentFrame = Math.floorMod(__index, _nbFrames);
    } else {
      _currentFrame = Math.max(0, Math.min(__index, _nbFrames - 1));
    }
    _updateFrame();
  }

  /**
   * go to millisecond of the BVH
   * @param mills millisecond
   */
  public void moveMsTo( int mills )
  {
    ensureMotionData();
    float frameTimeMs = _frameTime * 1000;
    int curFrame = (int)Math.floor(mills / frameTimeMs);
    moveFrameTo(curFrame);
  }
  
  /**
   * update bone position and rotation
   */
  public void update()
  {
    if (_rootBone == null) {
      throw new IllegalStateException("Parse BVH data before updating it");
    }
    update(_rootBone);
  }
  
  protected void update(BvhBone bone )
  {
    PMatrix3D m = new PMatrix3D();

    m.translate(bone.getXposition(), bone.getYposition(), bone.getZposition());
    m.translate(bone.getOffsetX(), bone.getOffsetY(), bone.getOffsetZ());

    m.rotateY(PApplet.radians(bone.getYrotation()));
    m.rotateX(PApplet.radians(bone.getXrotation()));
    m.rotateZ(PApplet.radians(bone.getZrotation()));

    bone.global_matrix = m;

    if (bone.getParent() != null && bone.getParent().global_matrix != null) {
      m.preApply(bone.getParent().global_matrix);
    }
    m.mult(new PVector(), bone.getAbsPosition());

    if (bone.hasChildren()) {
      for (BvhBone child : bone.getChildren()) {
        update(child);
      }
    } else {
      m.translate(bone.getEndOffsetX(), bone.getEndOffsetY(), bone.getEndOffsetZ());
      m.mult(new PVector(), bone.getAbsEndPosition());
    }
  }
  
  
  private void _updateFrame()
  {
    if (_currentFrame >= _frames.size()) {
      throw new IllegalStateException("Frame data is shorter than the declared frame count");
    }
    List<Float> frame = _frames.get(_currentFrame);
    int expectedValues = getChannelCount();
    if (frame.size() != expectedValues) {
      throw new IllegalStateException(
          "Frame " + _currentFrame + " has " + frame.size()
              + " values; expected " + expectedValues);
    }

    int valueIndex = 0;
    for (BvhBone bone : _bones) {
      for (String channel : bone.getChannels()) {
        applyChannel(bone, channel, frame.get(valueIndex));
        valueIndex++;
      }
    }
  }

  private void applyChannel(BvhBone bone, String channel, float value)
  {
    switch (channel) {
      case "Xposition": bone.setXposition(value); break;
      case "Yposition": bone.setYposition(value); break;
      case "Zposition": bone.setZposition(value); break;
      case "Xrotation": bone.setXrotation(value); break;
      case "Yrotation": bone.setYrotation(value); break;
      case "Zrotation": bone.setZrotation(value); break;
      default:
        throw new IllegalArgumentException("Unsupported BVH channel: " + channel);
    }
  }

  private int getChannelCount()
  {
    int count = 0;
    for (BvhBone bone : _bones) {
      count += bone.getNbChannels();
    }
    return count;
  }
  
  public void parse(String[] srces)
  {
    if (srces == null || srces.length < 2) {
      throw new IllegalArgumentException("BVH data is empty or incomplete");
    }

    boolean motionLoop = _motionLoop;
    init();
    _motionLoop = motionLoop;
    for (String lineStr : srces) {
      if (lineStr != null && !lineStr.trim().isEmpty()) {
        _lines.add(new BvhLine(lineStr));
      }
    }

    if (_lines.size() < 2 || !BvhLine.HIERARCHY.equals(_lines.get(0).getLineType())
        || !BvhLine.BONE.equals(_lines.get(1).getLineType())) {
      throw new IllegalArgumentException("BVH data must start with HIERARCHY and ROOT");
    }

    _currentLine = 1;
    try {
      _rootBone = _parseBone();
    } catch (IndexOutOfBoundsException e) {
      throw new IllegalArgumentException("BVH hierarchy is incomplete", e);
    }
    _parseFrames();
    ensureMotionData();
    _updateFrame();
  }
  
  private void _parseFrames()
  {
    int currentLine = _currentLine;
    for (; currentLine < _lines.size(); currentLine++)
      if (BvhLine.MOTION.equals(_lines.get(currentLine).getLineType())) break;

    if (currentLine >= _lines.size()) {
      throw new IllegalArgumentException("BVH data does not contain a MOTION section");
    }

    currentLine++;
    if (currentLine >= _lines.size()
        || !BvhLine.FRAMES.equals(_lines.get(currentLine).getLineType())) {
      throw new IllegalArgumentException("BVH MOTION section is missing Frames");
    }
    _nbFrames = _lines.get(currentLine).getNbFrames();

    currentLine++;
    if (currentLine >= _lines.size()
        || !BvhLine.FRAME_TIME.equals(_lines.get(currentLine).getLineType())) {
      throw new IllegalArgumentException("BVH MOTION section is missing Frame Time");
    }
    _frameTime = _lines.get(currentLine).getFrameTime();

    currentLine++;
    for (; currentLine < _lines.size(); currentLine++) {
      if (!BvhLine.FRAME.equals(_lines.get(currentLine).getLineType())) {
        throw new IllegalArgumentException("Unexpected line in BVH frame data");
      }
      _frames.add(_lines.get(currentLine).getFrames());
    }

    if (_frames.size() != _nbFrames) {
      throw new IllegalArgumentException(
          "BVH declares " + _nbFrames + " frames but contains " + _frames.size());
    }
  }

  private void ensureMotionData()
  {
    if (_nbFrames <= 0 || _frameTime <= 0 || _frames.isEmpty()) {
      throw new IllegalStateException("Parse valid BVH motion data before selecting a frame");
    }
  }
  
  private BvhBone _parseBone()
  {
    BvhBone bone = new BvhBone();
    
    _bones.add(bone);
    
    bone.setName(  _lines.get(_currentLine)._boneName ); //1
    
    // +2 OFFSET
    _currentLine++; // 2 {
    _currentLine++; // 3 OFFSET
    bone.setOffsetX( _lines.get(_currentLine).getOffsetX() );
    bone.setOffsetY( _lines.get(_currentLine).getOffsetY() );
    bone.setOffsetZ( _lines.get(_currentLine).getOffsetZ() );
      
    // +3 CHANNELS
    _currentLine++;
    bone.setnbChannels( _lines.get(_currentLine).getNbChannels() );
    bone.setChannels( _lines.get(_currentLine).getChannelsProps() );
      
    // +4 JOINT or End Site or }
    _currentLine++;
    while(_currentLine < _lines.size())
    {
      String lineType = _lines.get(_currentLine).getLineType();
      if ( BvhLine.BONE.equals( lineType ) ) //JOINT or ROOT
      {
        BvhBone child = _parseBone(); //generate new BvhBONE
        child.setParent( bone );
        bone.getChildren().add(child);
      }
      else if( BvhLine.END_SITE.equals( lineType ) )
      {
        _currentLine++; // {
        _currentLine++; // OFFSET
        bone.setEndOffsetX( _lines.get(_currentLine).getOffsetX() );
        bone.setEndOffsetY( _lines.get(_currentLine).getOffsetY() );
        bone.setEndOffsetZ( _lines.get(_currentLine).getOffsetZ() );
        _currentLine++; //}
        _currentLine++; //}
        return bone;
      } 
      else if( BvhLine.BRACE_CLOSED.equals( lineType ) )
      {
        return bone; //}
      }
      _currentLine++;
    }
    throw new IllegalArgumentException("Unexpected end of BVH hierarchy near " + bone.getName());
  }    
  
  private class BvhLine
  {
  
    public static final String HIERARCHY = "HIERARCHY";
    public static final String BONE = "BONE";
    public static final String BRACE_OPEN = "BRACE_OPEN";
    public static final String BRACE_CLOSED = "BRACE_CLOSED";
    public static final String OFFSET = "OFFSET";
    public static final String CHANNELS = "CHANNELS";
    public static final String END_SITE = "END_SITE";
    
    public static final String MOTION = "MOTION";
    public static final String FRAMES = "FRAMES";
    public static final String FRAME_TIME = "FRAME_TIME";
    public static final String FRAME = "FRAME";
    
    
    public static final String BONE_TYPE_ROOT = "ROOT";
    public static final String BONE_TYPE_JOINT = "JOINT";
    
    private String _lineStr;
    
    private String _lineType;
    private String _boneType;
    
    private String _boneName;
    private float _offsetX;
    private float _offsetY;
    private float _offsetZ;
    private int _nbChannels;
    private List<String> _channelsProps;
    private int _nbFrames;
    private float _frameTime;
    private List<Float> _frames;
    
    public String toString() 
    {
      return _lineStr;
    }
    
    private void _parse(String __lineStr)
    {
      _lineStr = __lineStr.trim();
      String[] words = _lineStr.split("\\s+");
    
      _lineType = _parseLineType(words);
      
  //    
      if ( HIERARCHY.equals(_lineType) )
      {
        return;
      } else if ( BONE.equals(_lineType) ) {
          _boneType = ("ROOT".equals(words[0])) ? BONE_TYPE_ROOT : BONE_TYPE_JOINT;
          _boneName = words[1];
          return;
      } else if ( OFFSET.equals(_lineType) ) {
          _offsetX = Float.valueOf(words[1]);
          _offsetY = Float.valueOf(words[2]);
          _offsetZ = Float.valueOf(words[3]);
          return;
      } else if ( CHANNELS.equals(_lineType) ) {
          _nbChannels = Integer.valueOf(words[1]);
          _channelsProps = new ArrayList<String>();
          for (int i = 0; i < _nbChannels; i++)
            _channelsProps.add(words[i+2]);
          return;
        
      } else if (FRAMES.equals(_lineType) ) {
          _nbFrames = Integer.valueOf(words[1]);
          return;
      } else if ( FRAME_TIME.equals(_lineType) ) {
          _frameTime = Float.valueOf(words[2]);
          return;
      } else if ( FRAME.equals(_lineType) ) {
          _frames = new ArrayList<Float>();
          for (String word : words) _frames.add(Float.valueOf(word));
          return;
      } else if ( END_SITE.equals(_lineType) ||
            BRACE_OPEN.equals(_lineType) ||
            BRACE_CLOSED.equals(_lineType) ||
            MOTION.equals(_lineType)) {
          return;
      }
    }  
    
    private String _parseLineType( String[] __words) {
      //trace("'" + __words[0] + "' : " + __words[0].length);
      if ( "HIERARCHY".equals(__words[ 0 ] ) )
        return HIERARCHY;
      if ( "ROOT".equals(__words[ 0 ] ) ||
          "JOINT".equals(__words[ 0 ] ) )
        return BONE;
      if ( "{".equals(__words[ 0 ] ) )
        return BRACE_OPEN;
      if ( "}".equals(__words[ 0 ] ) )
        return BRACE_CLOSED;
      if ( "OFFSET".equals(__words[ 0 ] ) )
        return OFFSET;
      if ( "CHANNELS".equals(__words[ 0 ] ) )
        return CHANNELS;
      if ( "End".equals(__words[ 0 ] ) )
        return END_SITE;
      if ( "MOTION".equals(__words[ 0 ] ) )
        return MOTION;
      if ( "Frames:".equals(__words[ 0 ] ) )
        return FRAMES;
      if ( "Frame".equals(__words[ 0 ] ) )
        return FRAME_TIME;
    
      try {
        Float.parseFloat(__words[0]); // Check whether the line starts with a frame value.
        return FRAME;  
      } catch ( NumberFormatException e) {
        throw new IllegalArgumentException("Unsupported BVH line: " + _lineStr, e);
      }
    }
  
    
    public BvhLine(String __lineStr)
    {
      _parse(__lineStr);
    }
    
    public List<Float> getFrames()
    {
      return _frames;
    }
    
    public float getFrameTime()
    {
      return _frameTime;
    }
    
    public int getNbFrames()
    {
      return _nbFrames;
    }
    
    public List<String> getChannelsProps()
    {
      return _channelsProps;
    }
    
    public int getNbChannels()
    {
      return _nbChannels;
    }
    
    public float getOffsetZ()
    {
      return _offsetZ;
    }
    
    public float getOffsetY()
    {
      return _offsetY;
    }
    
    public float getOffsetX()
    {
      return _offsetX;
    }
    
    public String getBoneName()
    {
      return _boneName;
    }
    
    public String getBoneType()
    {
      return _boneType;
    }
    
    public String getLineType()
    {
      return _lineType;
    }
  }
}
