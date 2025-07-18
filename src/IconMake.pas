﻿{$apptype windows}

{$reference System.Drawing.dll}
{$reference System.Windows.Forms.dll}

{$resource res\icon.ico}
{$resource res\clear.png}
{$resource res\add.png}
{$resource res\compile.png}

{$mainresource res\res.res}


uses
  System,
  System.IO,
  System.Diagnostics,
  System.Drawing,
  System.Drawing.Drawing2D,
  System.Windows.Forms;


var
  Main         : Form;
  Sources      : ListBox;
  SettingsBox  : GroupBox;
  BySources    : RadioButton;
  ByScaling    : RadioButton;
  FrameSizeBox : Panel;
  FrameSize    := new CheckBox[8];
  FrameSizes   := new integer[8](16, 24, 32, 48, 64, 80, 128, 256);
  ColorEnable  : CheckBox;
  ColorSelect  : &Label;
  AddSource    : Button;
  MakeIcon     : Button;


{$region Utils}
function ImageLoad(fname: string): Bitmap;
begin
  result := nil;
  try
    result := new Bitmap(fname);
  except on ex: Exception do
    MessageBox.Show($'Load file "{fname}" error: {ex.Message}', 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
  end;
end;

function ImageScale(img: Bitmap; width: integer): Bitmap;
begin
  result := new Bitmap(width, width);
  var g  := Graphics.FromImage(result);
  
  g.PageUnit           := GraphicsUnit.Pixel;
  g.InterpolationMode  := InterpolationMode.High;
  g.CompositingQuality := CompositingQuality.HighQuality;
  g.SmoothingMode      := SmoothingMode.AntiAlias;
  
  g.DrawImage(img, 0.0, 0.0, width-0.5, width-0.5);
end;

procedure IconBuild(fname: string; frames: array of Bitmap);
begin
  var n := frames.Length;
  var s := 6 + 16 * n + 40 * n;
  for var i := 0 to n-1 do
    s += 4 * (frames[i].Width + 1) * frames[i].Height;
  
  var data := new byte[s];
  var ep   := 0;
  var bp   := 6 + 16 * n;
  /// ICO_FILE_HEADER
  &Array.Copy(BitConverter.GetBytes($0000),                  0, data, ep, sizeof(UInt32)); ep += sizeof(UInt16);
  &Array.Copy(BitConverter.GetBytes($0001),                  0, data, ep, sizeof(UInt32)); ep += sizeof(UInt16);
  &Array.Copy(BitConverter.GetBytes(n),                      0, data, ep, sizeof(UInt16)); ep += sizeof(UInt16);
  /// ICO_ENTRIES
  for var i := 0 to n-1 do
    begin
      s := 4 * (frames[i].Width + 1) * frames[i].Height;
      /// ICO_ENTRY
      data[ep] := frames[i].Width;  ep += 1;
      data[ep] := frames[i].Height; ep += 1;
      data[ep] := $00;              ep += 1;
      data[ep] := $00;              ep += 1;
      &Array.Copy(BitConverter.GetBytes(1),                  0, data, ep, sizeof(UInt16)); ep += sizeof(UInt16);
      &Array.Copy(BitConverter.GetBytes(32),                 0, data, ep, sizeof(UInt16)); ep += sizeof(UInt16);
      &Array.Copy(BitConverter.GetBytes(40+s),               0, data, ep, sizeof(UInt32)); ep += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(bp),                 0, data, ep, sizeof(UInt32)); ep += sizeof(UInt32);
      /// BMP_INFO_HEADER
      &Array.Copy(BitConverter.GetBytes(40),                 0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(frames[i].Width),    0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(frames[i].Height*2), 0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(word(1)),            0, data, bp, sizeof(UInt16)); bp += sizeof(UInt16);
      &Array.Copy(BitConverter.GetBytes(word(32)),           0, data, bp, sizeof(UInt16)); bp += sizeof(UInt16);
      &Array.Copy(BitConverter.GetBytes(0),                  0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(s),                  0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(0),                  0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(0),                  0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(0),                  0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      &Array.Copy(BitConverter.GetBytes(0),                  0, data, bp, sizeof(UInt32)); bp += sizeof(UInt32);
      /// BMP_DATA
      for var y := frames[i].Height-1 downto 0 do
        for var x := 0 to frames[i].Width-1 do
          begin
            var c    := frames[i].GetPixel(x, y);
            data[bp] := c.B; bp += 1;
            data[bp] := c.G; bp += 1;
            data[bp] := c.R; bp += 1;
            data[bp] := c.A; bp += 1;
          end;
      /// WTF?
      for var y := frames[i].Height-1 downto 0 do
        begin
          data[bp] := $00; bp += 1;
          data[bp] := $00; bp += 1;
          data[bp] := $00; bp += 1;
          data[bp] := $00; bp += 1;
        end;
    end;
  
  &File.WriteAllBytes(fname, data);
end;

procedure Bitmap.DoTransparent(key: Color);
begin
  for var x := 0 to self.Width-1 do
    for var y := 0 to self.Height-1 do
      if self.GetPixel(x, y) = key then
        self.SetPixel(x, y, Color.FromArgb($00, $00, $00, $00));
end;
{$endregion}

{$region Handlers}
procedure SettingsRadioButtonCheckedChanged(sender: object; e: EventArgs);
begin
  FrameSizeBox.Enabled := ByScaling.Checked;
  
  if ByScaling.Checked and (Sources.Items.Count > 1) then
    Sources.Items.Clear();
end;

procedure ColorSelectClick(sender: object; e: EventArgs);
begin
  var dialog   := new ColorDialog();
  dialog.Color := ColorSelect.ForeColor;
  
  if dialog.ShowDialog() = DialogResult.OK then
    begin
      ColorSelect.ForeColor := Color.FromArgb($FF, dialog.Color.R, dialog.Color.G, dialog.Color.B);
      ColorSelect.Text      := $'#{dialog.Color.R:X2}{dialog.Color.G:X2}{dialog.Color.B:X2}';
    end;
end;

procedure AddSourceClick(sender: object; e: EventArgs);
begin
  var dialog         := new OpenFileDialog();
  dialog.Title       := 'Select image source file';
  dialog.Multiselect := BySources.Checked;
  dialog.Filter      := 'Portable Network Graphics (*.png)|*.png|'   +
                        'Windows Bitmap (*.bmp)|*.bmp|'              +
                        'Photo Picture (*.jpg;*.jpeg)|*.jpg;*.jpeg|' +
                        'Graphics Interchange (*.gif)|*.gif';
  dialog.FilterIndex := 0;
  
  if dialog.ShowDialog() = DialogResult.OK then
    begin
      if BySources.Checked then
        foreach var src in dialog.FileNames do
          Sources.Items.Add(src)
      else
        Sources.Items.Add(dialog.FileName);
    end;
end;

procedure MakeIconClick(sender: object; e: EventArgs);
begin
  var dialog    := new SaveFileDialog();
  dialog.Title  := 'Select destination file';
  dialog.Filter := 'Windows Icon (*.ico)|*.ico';
  
  if dialog.ShowDialog() = DialogResult.OK then
    begin
      if Sources.Items.Count > 0 then
        begin
          var frames: array of Bitmap;
          
          if BySources.Checked then
            begin
              frames := new Bitmap[Sources.Items.Count];
              for var i := 0 to Sources.Items.Count-1 do
                begin
                  frames[i] := ImageLoad(Sources.Items[i].ToString());
                  
                  if frames[i] = nil then
                    exit;
                end;
              
              if ColorEnable.Checked then
                for var i := 0 to frames.Length-1 do
                  frames[i].DoTransparent(ColorSelect.ForeColor);
            end
          else
            begin
              var src := ImageLoad(Sources.Items[0].ToString());
              
              if src = nil then
                exit;
              
              if ColorEnable.Checked then
                src.DoTransparent(ColorSelect.ForeColor);
              
              var count := Convert.ToInt32(FrameSize.Sum(cb->cb.Checked?1:0));
              if count > 0 then
                begin
                  var n  := 0;
                  frames := new Bitmap[count];
                  for var i := 0 to 7 do
                    if FrameSize[i].Checked then
                      begin
                        var width := integer(FrameSize[i].Tag);
                        frames[n] := width <> src.Width ? ImageScale(src, width) : Bitmap(src.Clone());
                        n += 1;
                      end;
                end
              else
                MessageBox.Show('Not selected frame sizes.', 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
            end;
          
          IconBuild(dialog.FileName, frames);
          
          (*if &File.Exists('rc.exe') and &File.Exists('rcdll.dll') then
            begin
              var fi := new FileInfo(dialog.FileName);
              
              &File.WriteAllText(fi.DirectoryName+'\res.rc', 'MAINICON ICON "'+fi.Name+'"');
              
              Process.Start('rc.exe', fi.DirectoryName+'\res.rc');
            end;*)
        end
      else
        MessageBox.Show('Not selected image source files.', 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
    end;
end;
{$endregion}

begin
  {$region App}
  Application.EnableVisualStyles();
  Application.SetCompatibleTextRenderingDefault(false);
  {$endregion}
  
  {$region MainForm}
  Main               := new Form();
  Main.Size          := new Size(510, 260);
  Main.MinimumSize   := new Size(510, 260);
  Main.Icon          := new Icon(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('icon.ico'));
  Main.StartPosition := FormStartPosition.CenterScreen;
  Main.Text          := 'IconMake';
  {$endregion}
  
  {$region Sources}
  var SourcesMenu := new ContextMenuStrip();
  
  var SourcesClear   := new ToolStripMenuItem();
  SourcesClear.Text  := 'Clear'; 
  SourcesClear.Image := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('clear.png'));
  SourcesClear.Click += (sender, e) -> begin Sources.Items.Clear(); end;
  SourcesMenu.Items.Add(SourcesClear);
  
  Sources                  := new ListBox();
  Sources.Size             := new Size(300, 220);
  Sources.Location         := new Point(5, 5);
  Sources.Anchor           := AnchorStyles.Left or AnchorStyles.Top or AnchorStyles.Right or AnchorStyles.Bottom;
  Sources.ContextMenuStrip := SourcesMenu;
  Sources.AllowDrop        := true;
  Sources.DragEnter        += (sender, e) -> begin e.Effect := DragDropEffects.All; end;
  Sources.DragDrop         += (sender, e) ->
    begin
      var files := e.Data.GetData(DataFormats.FileDrop) as array of string;
      for var i := 0 to files.Length-1 do
        Sources.Items.Add(files[i]);
    end;
  Main.Controls.Add(Sources);
  {$endregion}
  
  {$region Settings}
  SettingsBox          := new GroupBox();
  SettingsBox.Size     := new Size(180, 183);
  SettingsBox.Location := new Point(Sources.Left+Sources.Width+5, 5);
  SettingsBox.Anchor   := AnchorStyles.Top or AnchorStyles.Right or AnchorStyles.Bottom;
  SettingsBox.Text     := 'Settings';
  Main.Controls.Add(SettingsBox);
  
  BySources                := new RadioButton();
  BySources.Size           := new Size(170, 20);
  BySources.Location       := new Point(5, 15);
  BySources.Text           := 'By source image list';
  BySources.Checked        := true;
  BySources.CheckedChanged += SettingsRadioButtonCheckedChanged;
  SettingsBox.Controls.Add(BySources);
  
  ByScaling                := new RadioButton();
  ByScaling.Size           := new Size(170, 20);
  ByScaling.Location       := new Point(5, 35);
  ByScaling.Text           := 'By scaling one source image';
  ByScaling.CheckedChanged += SettingsRadioButtonCheckedChanged;
  SettingsBox.Controls.Add(ByScaling);
  
  FrameSizeBox          := new Panel();
  FrameSizeBox.Size     := new Size(150, 70);
  FrameSizeBox.Location := new Point(20, 55);
  FrameSizeBox.Enabled  := false;
  SettingsBox.Controls.Add(FrameSizeBox);
  
  for var i := 0 to 7 do
    begin
      FrameSize[i]          := new CheckBox();
      FrameSize[i].Size     := new Size(70, 15);
      FrameSize[i].Location := new Point(75*(i div 4), 5+15*(i mod 4));
      FrameSize[i].Text     := String.Format('{0}x{0}', FrameSizes[i]);
      FrameSize[i].Tag      := FrameSizes[i];
      FrameSizeBox.Controls.Add(FrameSize[i]);
    end;
  
  ColorEnable          := new CheckBox();
  ColorEnable.Size     := new Size(170, 19);
  ColorEnable.Location := new Point(5, 130);
  ColorEnable.Text     := 'Transparent color';
  SettingsBox.Controls.Add(ColorEnable);
  
  ColorSelect             := new &Label();
  ColorSelect.Size        := new Size(170, 25);
  ColorSelect.Location    := new Point(5, 150);
  ColorSelect.BorderStyle := BorderStyle.FixedSingle;
  ColorSelect.Font        := new Font('Consolas', 10, FontStyle.Regular, GraphicsUnit.Point);
  ColorSelect.TextAlign   := ContentAlignment.MiddleCenter;
  ColorSelect.Text        := '#FF0000';
  ColorSelect.BackColor   := Color.White;
  ColorSelect.ForeColor   := Color.FromArgb($FF, $FF, $00, $00);
  ColorSelect.Cursor      := Cursors.Hand;
  ColorSelect.Click       += ColorSelectClick;
  SettingsBox.Controls.Add(ColorSelect);
  {$endregion}
  
  {$region Actions}
  AddSource            := new Button();
  AddSource.Size       := new Size(85, 24);
  AddSource.Location   := new Point(SettingsBox.Left, SettingsBox.Top+SettingsBox.Height+5);
  AddSource.Anchor     := AnchorStyles.Right or AnchorStyles.Bottom;
  AddSource.Text       := '  Source';
  AddSource.ImageAlign := ContentAlignment.MiddleLeft;
  AddSource.Image      := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('add.png'));
  AddSource.Click      += AddSourceClick;
  Main.Controls.Add(AddSource);
  
  MakeIcon            := new Button();
  MakeIcon.Size       := new Size(85, 24);
  MakeIcon.Location   := new Point(AddSource.Left+AddSource.Width+10, SettingsBox.Top+SettingsBox.Height+5);
  MakeIcon.Anchor     := AnchorStyles.Right or AnchorStyles.Bottom;
  MakeIcon.Text       := '  Icon';
  MakeIcon.ImageAlign := ContentAlignment.MiddleLeft;
  MakeIcon.Image      := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('compile.png'));
  MakeIcon.Click      += MakeIconClick;
  Main.Controls.Add(MakeIcon);
  {$endregion}
  
  {$region App}
  begin
    var args := Environment.GetCommandLineArgs();
    
    if args.Length > 1 then
      for var i := 1 to args.Length-1 do
        Sources.Items.Add(args[i].Trim('"'));
  end;
  
  Application.Run(Main);
  {$endregion}
end.


{$region Structure}
(*
BMP_FILE_HEADER[14]
  0000: uint16_t Type
  0002: uint32_t Size
  0006: uint16_t Reserved1
  0008: uint16_t Reserved2
  000A: uint32_t Offset

BMP_INFO_HEADER[40]
  0000: uint32_t Size
  0004: uint32_t Width
  0008: uint32_t Height
  000C: uint16_t Planes
  000E: uint16_t BitCount
  0010: uint32_t Compression
  0014: uint32_t ImageSize
  0018: uint32_t PxPerMeterX
  001C: uint32_t PxPerMeterY
  0020: uint32_t ColorUsed
  0024: uint32_t ColorImport

ICO_FILE_HEADER[6]
  0000: uint16_t Reserved
  0002: uint16_t Type
  0004: uint16_t Count

ICO_ENTRY[16]
  0000: uint08_t Width
  0001: uint08_t Height
  0002: uint08_t ColorCount
  0003: uint08_t Reserved
  0004: uint16_t Planes
  0006: uint16_t BitCount
  0008: uint32_t Size
  000C: uint32_t Offset
*)
{$endregion}