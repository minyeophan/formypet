import { useEffect, useState } from 'react';
import { Modal, Pressable, View, StyleSheet, Text } from 'react-native'; 
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { colors } from '@/src/lib/colors';

interface Props {
  visible: boolean;
  label?: string;
  unit?: string;
  initialValue?: string;
  allowDecimal?: boolean;
  onConfirm: (value: string) => void;
  onCancel: () => void;
}

const ROWS = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['.', '0', '⌫']];

export default function NumericInputModal({
  visible, label, unit, initialValue = '', allowDecimal = true, onConfirm, onCancel,
}: Props) {
  const insets = useSafeAreaInsets();
  const [val, setVal] = useState('');

  useEffect(() => {
    if (visible) setVal(initialValue);
  }, [visible, initialValue]);

  function append(d: string) {
    if (d === '.') {
      if (!allowDecimal || val.includes('.')) return;
      setVal(prev => (prev === '' ? '0.' : prev + '.'));
      return;
    }
    setVal(prev => (prev === '0' ? d : prev + d));
  }

  function backspace() {
    setVal(prev => prev.slice(0, -1));
  }

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onCancel} statusBarTranslucent>
      <View style={styles.modalOverlay}>
        <Pressable style={styles.backdrop} onPress={onCancel} />
        
        <View style={[styles.sheetContainer, { paddingBottom: insets.bottom + 20 }]}>
          <View style={styles.handle} />

          {label && <Text style={styles.label}>{label}</Text>}

          {/* 값 표시창 */}
          <View style={styles.displayContainer}>
            <Text style={[styles.displayText, { color: val ? '#1A1A1A' : '#B0A99F' }]}>
              {val || '0'}
              {unit && <Text style={styles.unitText}> {unit}</Text>}
            </Text>
          </View>

          <Pressable onPress={() => setVal('')} style={styles.resetButton}>
            <Text style={styles.resetText}>초기화</Text>
          </Pressable>

          {/* 숫자 그리드 - 구조 변경 */}
          <View style={styles.gridContainer}>
            {ROWS.map((row, ri) => (
              <View key={ri} style={styles.row}>
                {row.map((btn) => {
                  const isDecimal = btn === '.';
                  const disabled = isDecimal && !allowDecimal;
                  
                  return (
                    <Pressable
                      key={btn}
                      onPress={() => (btn === '⌫' ? backspace() : append(btn))}
                      disabled={disabled}
                      style={{ width: '31%' }} // Pressable은 너비만 담당
                    >
                      {/* 실제 배경을 그리는 View를 내부에 배치 */}
                      <View style={[
                        styles.keyBox,
                        { backgroundColor: disabled ? '#F5F3EF' : '#F0EDE8' }
                      ]}>
                        {btn === '⌫' ? (
                          <Ionicons name="backspace-outline" size={24} color="#1A1A1A" />
                        ) : (
                          <Text style={[styles.keyText, { color: disabled ? '#D4CFC8' : '#1A1A1A' }]}>
                            {btn}
                          </Text>
                        )}
                      </View>
                    </Pressable>
                  );
                })}
              </View>
            ))}
          </View>

          {/* 하단 버튼 */}
          <View style={styles.actionContainer}>
            <Pressable onPress={onCancel} style={styles.cancelButton}>
              <View style={styles.cancelBox}>
                <Text style={styles.cancelText}>취소</Text>
              </View>
            </Pressable>
            <Pressable onPress={() => onConfirm(val)} style={styles.confirmButton}>
              <View style={[styles.confirmBox, { backgroundColor: colors.primary }]}>
                <Text style={styles.confirmText}>확인</Text>
              </View>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalOverlay: { flex: 1, justifyContent: 'flex-end' },
  backdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.35)' },
  sheetContainer: {
    backgroundColor: '#FFFFFF',
    borderTopLeftRadius: 24, borderTopRightRadius: 24,
    paddingHorizontal: 20, paddingTop: 20,
    width: '100%',
  },
  handle: { width: 36, height: 4, borderRadius: 2, backgroundColor: '#D4CFC8', alignSelf: 'center', marginBottom: 16 },
  label: { fontSize: 15, color: '#6B6B6B', marginBottom: 12, textAlign: 'center', fontWeight: '600' },
  displayContainer: {
    alignItems: 'center', justifyContent: 'center',
    backgroundColor: '#F5F3EF', borderRadius: 16,
    paddingVertical: 18, marginBottom: 8, minHeight: 72,
  },
  displayText: { fontSize: 38, fontWeight: '700' },
  unitText: { fontSize: 20, color: '#6B6B6B', fontWeight: '400' },
  resetButton: { alignSelf: 'center', paddingVertical: 6, marginBottom: 12 },
  resetText: { fontSize: 13, color: '#B0A99F' },
  gridContainer: { width: '100%' },
  row: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 10 },
  // 핵심: 배경을 그리는 박스 스타일
  keyBox: {
    height: 60,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
  },
  keyText: { fontSize: 24, fontWeight: '600' },
  actionContainer: { flexDirection: 'row', gap: 10, marginTop: 4 },
  cancelButton: { flex: 1 },
  cancelBox: { paddingVertical: 16, borderRadius: 14, backgroundColor: '#F5F3EF', alignItems: 'center' },
  cancelText: { fontSize: 15, color: '#3A3A3A' },
  confirmButton: { flex: 2 },
  confirmBox: { paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  confirmText: { fontSize: 15, color: '#FFFFFF', fontWeight: '700' },
});