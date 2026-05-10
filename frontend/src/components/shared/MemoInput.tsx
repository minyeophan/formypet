import { useState } from 'react';
import { Keyboard, Platform, Pressable, TextInput, View } from 'react-native';
import { colors } from '@/src/lib/colors';
import AppText from './AppText';

// BottomSheetTextInput은 웹에서 currentlyFocusedInput 오류 발생 → native에서만 사용
let SheetInput: typeof TextInput = TextInput;
if (Platform.OS !== 'web') {
  SheetInput = require('@gorhom/bottom-sheet').BottomSheetTextInput;
}

const MIN_H = 72;

interface Props {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  maxLength?: number;
  maxHeight?: number;
  inBottomSheet?: boolean;
  onFocus?: () => void;
}

export default function MemoInput({
  value,
  onChange,
  placeholder = '메모를 입력해 주세요',
  maxLength = 200,
  maxHeight = 180,
  inBottomSheet = false,
  onFocus,
}: Props) {
  const [focused, setFocused] = useState(false);
  const [scrollable, setScrollable] = useState(false);

  const Input = (inBottomSheet && Platform.OS !== 'web') ? SheetInput : TextInput;

  return (
    <View>
      <Input
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor="#B0A99F"
        multiline
        maxLength={maxLength}
        scrollEnabled={scrollable}
        onFocus={() => {
          setFocused(true);
          onFocus?.();
        }}
        onBlur={() => setFocused(false)}
        onContentSizeChange={(e) => {
          setScrollable(e.nativeEvent.contentSize.height + 22 >= maxHeight);
        }}
        style={{
          backgroundColor: '#F5F3EF',
          borderRadius: 12,
          borderWidth: 1.5,
          borderColor: focused ? colors.primary : '#F5F3EF',
          paddingHorizontal: 16,
          paddingVertical: 11,
          fontSize: 15,
          color: '#1A1A1A',
          minHeight: MIN_H,
          maxHeight,
          textAlignVertical: 'top',
        }}
      />
      <AppText style={{ fontSize: 11, color: '#B0A99F', textAlign: 'right', marginTop: 4 }}>
        {value.length}/{maxLength}
      </AppText>
      {focused && (
        <View style={{ alignItems: 'flex-end', marginTop: 8 }}>
          <Pressable
            onPress={Keyboard.dismiss}
            style={{ backgroundColor: colors.primary, borderRadius: 12, paddingHorizontal: 14, paddingVertical: 8 }}
          >
            <AppText bold style={{ color: '#FFFFFF', fontSize: 13 }}>완료</AppText>
          </Pressable>
        </View>
      )}
    </View>
  );
}
