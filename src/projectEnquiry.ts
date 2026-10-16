export function validateEnquiry(brief:string,contact:string):string|null{
 if(brief.trim().length<20)return 'Опишите задачу минимум в 20 значимых символах.'
 if(brief.length>5000||contact.length>250)return 'Сократите описание до 5000 символов, а контакт — до 250.'
 return null
}
export function formatEnquiry(brief:string,contact:string){
 const error=validateEnquiry(brief,contact);if(error)throw Error(error)
 return `OSGARD / PROJECT BRIEF\n\nЗадача:\n${brief.trim()}\n\nПредпочтительный контакт:\n${contact.trim()||'Не указан'}\n\nЭто локальный файл. Заявка не отправлена.\n`
}
