import { coreRequest } from './coreClient';

export type CommerceConfiguration = {
  enabled: boolean; canManage: boolean; mode: 'test' | 'live'; currencies: string[];
  oneTimeOnly: boolean; livePaymentTested: boolean;
};
export type CommerceOrder = {
  id: string; version: number; title: string; scope: string;
  amountMinor: number; currency: string; status: string; mode: 'test' | 'live';
  paidMinor: number; refundedMinor: number; checkoutConfirmed: boolean; accessGranted: boolean;
  checkoutState: string | null; refundState: string | null; refundTargetMinor: number | null;
  buyer?: string; sourceOrderId?: string; releaseId?: string; createdAt: string; updatedAt: string;
  kind?: 'html_release' | 'learning_program'; program?: ProgramHeader; enrollmentActivated?: boolean;
};
export type ProgramHeader = {
  programId: string; version: string; policyVersion: string; title: string; scope: string;
  mentorIncluded: boolean; lessonCount: number; freeModule: string;
};
export const commerceStatus: Record<string, string> = {
  prepared: 'Готов к оплате', checkout_pending: 'Запрос оплаты отправлен', checkout_open: 'Ожидает оплаты',
  payment_processing: 'Ожидает подтверждения оплаты', paid: 'Оплата подтверждена',
  partially_refunded: 'Частичный возврат', refunded: 'Полный возврат',
  expired: 'Срок оплаты истёк', failed: 'Оплата не завершена', cancelled: 'Закрыт',
};
const requestKeys = new Map<string, string>();
export function commerceMutation<T>(route: string, body: Record<string, unknown> = {}): Promise<T> {
  const operation = route + ':' + JSON.stringify(body);
  let key = requestKeys.get(operation);
  if (!key) { key = crypto.randomUUID(); requestKeys.set(operation, key); }
  // The server also persists its own provider key across reloads and devices.
  return coreRequest<T>(route, body, key);
}
